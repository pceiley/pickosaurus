#!/usr/bin/env python3
"""Build two static Pages documents using only Python's standard library."""
import argparse
import html
import json
import os
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repository', help='GitHub owner/repository (defaults to site.json or GITHUB_REPOSITORY)')
args = parser.parse_args()
config = json.loads((ROOT / 'docs/site.json').read_text())
repository = args.repository or config['repository'] or os.environ.get('GITHUB_REPOSITORY', '')
if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9._-]*', repository):
    parser.error('Set docs/site.json repository, --repository owner/repository, or GITHUB_REPOSITORY.')
repo_url = 'https://github.com/' + repository
brew = config['homebrew_command'].strip()
if brew and not re.fullmatch(r'brew install --cask [A-Za-z0-9][A-Za-z0-9_./-]*', brew):
    parser.error('homebrew_command must be a single brew install --cask command.')
contact = config['privacy_contact'].strip()
if contact and not re.fullmatch(r'[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', contact):
    parser.error('privacy_contact must be an email address, or empty to use GitHub issues.')

policy = (ROOT / 'Pickosaurus/Resources/privacy.txt').read_text().strip()
paragraphs = policy.split('\n\n')
policy_html = '\n'.join(
    '<h1>' + html.escape(p[2:]) + '</h1>' if p.startswith('# ') else
    '<p class="effective">' + html.escape(p) + '</p>' if p.startswith('Effective ') else
    '<p>' + html.escape(p) + '</p>' for p in paragraphs
)
if contact:
    contact_html = '<a href="mailto:' + html.escape(contact, quote=True) + '">' + html.escape(contact) + '</a>'
else:
    contact_html = '<a href="' + repo_url + '/issues">Contact the maintainer on GitHub</a>'
if brew:
    brew_html = '<p>Install the published cask:</p><pre aria-label="Homebrew command"><code>' + html.escape(brew) + '</code></pre>'
else:
    brew_html = '<p>Coming later. For now, <a href="' + repo_url + '/blob/main/README.md#build-and-run">build from source</a>.</p>'
replacements = {
    '@@REPOSITORY_URL@@': repo_url,
    '@@SOURCE_URL@@': repo_url + '/blob/main/README.md#build-and-run',
    '@@ISSUES_URL@@': repo_url + '/issues',
    '@@HOMEBREW_HTML@@': brew_html,
    '@@POLICY_HTML@@': policy_html,
    '@@CONTACT_HTML@@': contact_html,
}
output = ROOT / 'build/site'
if output.exists():
    shutil.rmtree(output)
output.mkdir(parents=True)
for filename in ['index.html', 'privacy.html']:
    page = (ROOT / 'docs' / filename).read_text()
    for token, value in replacements.items():
        page = page.replace(token, value)
    if re.search(r'@@[A-Z_]+@@', page):
        raise ValueError('Unresolved site token in ' + filename)
    (output / filename).write_text(page)
shutil.copyfile(ROOT / 'docs/styles.css', output / 'styles.css')
shutil.copytree(ROOT / 'docs/assets', output / 'assets')
(output / '.nojekyll').touch()
print('Built static site:', output)
