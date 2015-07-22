export CURR_DATE=$( date --iso-8601 )
export library="library_scireptor"
abs_path=$1

# set up library schemes
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb -e "CREATE SCHEMA IF NOT EXISTS ${library};"
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${library} < igdb_library.sql

# retrieve human/ mouse
# memorize output folder.
cd VDJ_segments
./retrieve_data_human_imgt.sh
./retrieve_data_mouse_ncbi.sh

echo "[OK] Setting up database for mouse VDJ."
./build_VDJ_db.pl -mysql_group mysql_igdb -lu segments_ncbi_mouse_2015-05-15.tsv -sp mouse -fa_dir data_ncbi_mouse_${CURR_DATE} -lib_scheme ${library} -log

echo "[OK] Setting up database for human VDJ."
./build_VDJ_db.pl -mysql_group mysql_igdb -lu segments_imgt_human_${CURR_DATE}.tsv -sp human -fa_dir data_imgt_human_${CURR_DATE} -lib_scheme ${library} -log


# constant segments (human and mouse), 
#
cd ../constant_segments/

echo "[OK] Setting up database for human constant."
cp human_gl_C.fasta ../igdata/database/human_gl_C
makeblastdb -dbtype nucl -in ../igdata/database/human_gl_C
rm ../igdata/database/human_gl_C
./build_constant_db.pl -mysql_group mysql_igdb -lib ${library} -sp human -fasta human_gl_C.fasta

echo "[OK] Setting up database for mouse constant."
cp mouse_gl_C.fasta ../igdata/database/mouse_gl_C
makeblastdb -dbtype nucl -in ../igdata/database/mouse_gl_C
rm ../igdata/database/mouse_gl_C
./build_constant_db.pl -mysql_group mysql_igdb -lib ${library} -sp mouse -fasta mouse_gl_C.fasta

# tags
#
cd ../tags
./upload_tags.pl

cd ..

echo "[OK] Setting up other databases (species, plate layout, tags)."
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${library} --local_infile=1 < load_lib_tables.sql
