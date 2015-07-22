This is the constant segment reference database.

The utilized sequence information is stored in the CSV file. The sequences
are retrieved from GenBank and the stretch delimited by pos_start and pos_end
is saved. While the start position is either derived from the existing
annotation in the GenBank record or - in case this information is not
available - as the first nucleotide after the end of the J-segment as
determined by IgBLAST. The length is arbitrarily set to 240 bp, which should
be sufficient for reliable identification, especially since most PCR based
processes will anyhow yield shorter sequences. In case the 'makeblastdb' tool
is available a database folder holding the blastn databases will automatically
be generated.

Note that for the mouse sequences not all sequences are derived from the
C57BL/6 strain and therefore can differ from the reference genome. However,
this was considered acceptable since the difference to other isotypes is large
enough to allow for unambiguous identification.
