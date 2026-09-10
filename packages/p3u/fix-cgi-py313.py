"""
Patch p3u.py to replace the removed-in-3.13 `cgi` module with `multipart`.

parse_form_data() returns (forms, files); files.get("file") has the same
.filename and .file attributes as cgi.FieldStorage's file fields.
"""
import pathlib

src = pathlib.Path("p3u.py").read_text()

# 1. Replace the `import cgi` line.
src = src.replace("import cgi\n", "from multipart import parse_form_data\n", 1)

# 2. Replace the cgi.FieldStorage block inside do_POST with parse_form_data.
old = (
    "        post_form = cgi.FieldStorage(\n"
    "            fp=self.rfile,\n"
    "            headers=self.headers,\n"
    "            environ={\n"
    "                \"REQUEST_METHOD\": \"POST\",\n"
    "                \"CONTENT_TYPE\": self.headers['Content-Type']\n"
    "            }\n"
    "        )\n"
    "        # Save File after uploading it.\n"
    "        dir_path = os.getcwd()\n"
    "        file_name = urllib.parse.unquote(post_form[\"file\"].filename)\n"
    "        valid_chars = \"-_.() %s%s\" % (string.ascii_letters, string.digits)\n"
    "        file_name = ''.join(c for c in file_name if c in valid_chars)\n"
    "        with open(dir_path + self.path + file_name, 'wb') as file_object:\n"
    "            shutil.copyfileobj(post_form[\"file\"].file, file_object)\n"
)
new = (
    "        _, files = parse_form_data({\n"
    "                \"REQUEST_METHOD\": \"POST\",\n"
    "                \"CONTENT_TYPE\": self.headers[\"Content-Type\"],\n"
    "                \"CONTENT_LENGTH\": self.headers.get(\"Content-Length\", \"\"),\n"
    "                \"wsgi.input\": self.rfile,\n"
    "            })\n"
    "        # Save File after uploading it.\n"
    "        dir_path = os.getcwd()\n"
    "        upload = files.get(\"file\")\n"
    "        file_name = urllib.parse.unquote(upload.filename)\n"
    "        valid_chars = \"-_.() %s%s\" % (string.ascii_letters, string.digits)\n"
    "        file_name = ''.join(c for c in file_name if c in valid_chars)\n"
    "        with open(dir_path + self.path + file_name, 'wb') as file_object:\n"
    "            shutil.copyfileobj(upload.file, file_object)\n"
)
assert old in src, "cgi.FieldStorage block not found -- upstream changed"
src = src.replace(old, new, 1)

pathlib.Path("p3u.py").write_text(src)
print("patch applied ok")
