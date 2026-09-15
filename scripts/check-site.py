#!/usr/bin/env python3
"""Validate generated site links and guard the no-script, local-assets policy."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import re

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / 'build/site'

class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids = set()
        self.links = []
        self.main_count = 0
        self.h1_count = 0
        self.csp = False
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        assert tag not in {'script', 'iframe', 'form', 'object', 'embed', 'base'}, (self.path, tag)
        assert not any(k.lower().startswith('on') or k == 'style' for k in attrs), self.path
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, (self.path, 'duplicate ID')
            self.ids.add(attrs['id'])
        if tag == 'main': self.main_count += 1
        if tag == 'h1': self.h1_count += 1
        if tag == 'meta' and attrs.get('http-equiv') == 'Content-Security-Policy':
            self.csp = "default-src 'none'" in attrs.get('content', '')
        if tag == 'img':
            assert 'alt' in attrs, self.path
        for attr in ('href', 'src'):
            if attr in attrs: self.links.append((attrs[attr], tag != 'a'))
        for item in attrs.get('srcset', '').split(','):
            if item.strip(): self.links.append((item.strip().split()[0], True))

pages = {p.name: Page(p) for p in SITE.glob('*.html')}
assert set(pages) == {'index.html', 'privacy.html'}
for page in pages.values():
    assert page.main_count == 1 and page.h1_count == 1 and page.csp, page.path
    assert not re.search(r'@@[A-Z_]+@@', page.path.read_text()), page.path
    for link, asset in page.links:
        parsed = urlsplit(link)
        if parsed.scheme:
            assert not asset and parsed.scheme in {'https', 'mailto'}, (page.path, link)
            continue
        assert not parsed.netloc, (page.path, link)
        target = (page.path.parent / unquote(parsed.path)).resolve() if parsed.path else page.path
        assert target.is_relative_to(SITE) and target.is_file(), (page.path, link)
        if parsed.fragment and target.suffix == '.html':
            assert parsed.fragment in pages[target.name].ids, (page.path, link)
css = (SITE / 'styles.css').read_text()
assert not re.search(r'@import|url\s*\(', css, re.I), 'CSS must not load external assets'
policy = (ROOT / 'Pickosaurus/Resources/privacy.txt').read_text()
assert (ROOT / 'PRIVACY.md').read_text().startswith(policy), 'Bundled and repository privacy policies differ'
print('PASS: site links, anchors, local assets, privacy policy consistency and no-script policy')
