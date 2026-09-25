# Zero-install text extraction from office files

docx, odt, and pptx are ZIP archives of XML parts. When python-docx/pypdf tooling is absent (or for read-only pulls you don't want to depend on installs), extract text with pure stdlib + `pdftotext` (poppler):

```python
import zipfile, re

def office_text(path):
    z = zipfile.ZipFile(path)
    if path.endswith('.docx'):
        parts = ['word/document.xml']
    elif path.endswith('.odt'):
        parts = ['content.xml']
    elif path.endswith('.pptx'):
        parts = [n for n in z.namelist() if n.startswith('ppt/slides/') and n.endswith('.xml')]
        parts.sort()  # slideN.xml sorts in numeric order
    else:
        raise ValueError(path)
    return '\n\n'.join(
        re.sub(r'<[^>]+>', '', z.read(p).decode('utf-8', 'ignore')) for p in parts
    )
```

- `word/document.xml` holds the docx body; `content.xml` the ODT body; `ppt/slides/slide*.xml` the PPTX slides (sort before joining to keep order).
- For PDFs with a text layer: `pdftotext -layout file.pdf -`. Scanned/image-only PDFs have no text layer — route them to `ocr-and-documents`; do not fabricate text.
- Paragraph breaks: regex-stripping tags loses `</w:p>` boundaries — for structure-sensitive reads, replace closing tags with `\n` before stripping (`re.sub(r'</w:p>', '\n', xml)` first).
- READ-ONLY: this pulls text out; never write modified XML back into the zip (corrupts the package — see the docx skill's unzip-sed warning).
- Normalize output filenames (spaces → underscores) when writing `.txt` files and glob with the same form later.

Proven for whole-corpus reads (18 letters + 7 resume versions in one pass).
