export CURR_DATE=$( date --iso-8601 )
export LIBRARY="library_scireptor"
export DIR_IGDATA_DB="igdata/database"

mkdir -p $DIR_IGDATA_DB

# set up library schemes
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb -e "CREATE SCHEMA IF NOT EXISTS ${LIBRARY};"
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${LIBRARY} < igdb_library.sql

# retrieve VDJ segment data (human and mouse)
#
cd VDJ_segments
./retrieve_data_human_imgt.sh "../${DIR_IGDATA_DB}"
./retrieve_data_mouse_igblast.sh "../${DIR_IGDATA_DB}"

echo "[OK] Setting up database for human VDJ."
./build_VDJ_db.pl -mysql_group mysql_igdb -lu segments_human_imgt_${CURR_DATE}.tsv -sp human -fa_dir data_human_imgt_${CURR_DATE} -lib_scheme ${LIBRARY} -log

# Use a fixed segment type lookup table for mouse, since the locus cannot be reconstructed from the IGBLAST libraries
echo "[OK] Setting up database for mouse VDJ."
./build_VDJ_db.pl -mysql_group mysql_igdb -lu segments_mouse_igblast_2015-05-15.tsv -sp mouse -fa_dir data_mouse_igblast_${CURR_DATE} -lib_scheme ${LIBRARY} -log


# constant segments (human and mouse), 
#
cd ../constant_segments/

./proc_constant_loci.sh constant_loci.csv

echo "[OK] Setting up database for human constant."
mv human_gl_C.fasta ../${DIR_IGDATA_DB}/human_gl_C
makeblastdb -dbtype nucl -in ../${DIR_IGDATA_DB}/human_gl_C
mv ../${DIR_IGDATA_DB}/human_gl_C ../${DIR_IGDATA_DB}/human_gl_C.fasta
./build_constant_db.pl -mysql_group mysql_igdb -lib ${LIBRARY} -sp human -fasta human_gl_C.fasta

echo "[OK] Setting up database for mouse constant."
mv mouse_gl_C.fasta ../${DIR_IGDATA_DB}/mouse_gl_C
makeblastdb -dbtype nucl -in ../${DIR_IGDATA_DB}/mouse_gl_C
mv ../${DIR_IGDATA_DB}/mouse_gl_C ../${DIR_IGDATA_DB}/mouse_gl_C.fasta
./build_constant_db.pl -mysql_group mysql_igdb -lib ${LIBRARY} -sp mouse -fasta mouse_gl_C.fasta

# process tags
#
cd ../tags
./process_tags.pl

cd ..

# Insert remaining tables into the database
#
echo "[OK] Setting up other databases (species, plate layout, tags)."
mysql --defaults-file=$HOME/.my.cnf --defaults-group-suffix=_igdb --database=${LIBRARY} --local_infile=1 < load_lib_tables.sql
