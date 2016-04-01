
-- SET @plate_file=(SELECT concat(@abs_path, '/library/plate_layout/plate_layout_library.csv'));
-- SET @species_file=(SELECT concat(@abs_path, '/library/species/species_library.csv'));
-- SET @tag_file=(SELECT concat(@abs_path, '/tags/tag_library.tsv'));

LOAD DATA LOCAL INFILE './plate_layout/plate_layout_library.csv' INTO TABLE plate_layout_library IGNORE 1 LINES;

LOAD DATA LOCAL INFILE './species/species_library.csv' INTO TABLE species_library IGNORE 1 LINES;

LOAD DATA LOCAL INFILE './tags/tag_library.tsv' INTO TABLE tags_library;

