
static NSString *dbschema = @"\
\
CREATE TABLE paths \
(id INTEGER PRIMARY KEY AUTOINCREMENT, \
path TEXT UNIQUE ON CONFLICT IGNORE, \
words_count INTEGER, \
moddate REAL); \
\
CREATE TABLE words \
(id INTEGER PRIMARY KEY AUTOINCREMENT, \
word TEXT UNIQUE ON CONFLICT IGNORE); \
\
CREATE TABLE postings \
(word_id INTEGER REFERENCES words(id), \
path_id INTEGER REFERENCES paths(id), \
score REAL); \
\
CREATE INDEX postings_wid_index ON postings(word_id); \
CREATE INDEX postings_pid_index ON postings(path_id, word_id); \
\
\
CREATE TABLE attributes \
(path_id INTEGER REFERENCES paths(id), \
key TEXT, \
attribute TEXT); \
\
CREATE INDEX attributes_path_index ON attributes(path_id); \
CREATE INDEX attributes_key_index ON attributes(key); \
CREATE INDEX attributes_attr_index ON attributes(attribute); \
";

