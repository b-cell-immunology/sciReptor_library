What is the purpose of the .TSV files?

The segment lists provided by IgBLAST do not contain any information on the
locus on which a given segment is located. Since it is not straight-forward
to infer this information from the segment name, a lookup-tables seems to
be the simplest solution. The .TSV file resolve each segment name to a 
two character string ("[VDJ][HKL]"), which encoded the segment type [1]
and the locus of origin [2].

Additional note:
The IgBLAST mouse database now also contains some lambda segments that are
derived from Mus spretus strains and are very distant from everything else.
The GenBank accession numbers are AF357975.1 to AF357987.1, the reference
is Immunogenetics 54:106 (2002) [http://www.ncbi.nlm.nih.gov/pubmed/12037603].
