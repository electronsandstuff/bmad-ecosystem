#!/usr/bin/perl

# To web page

`pdflatex tutorial_bmad_tao`; 
`chmod g+w tutorial_bmad_tao.pdf`;
`cp tutorial_bmad_tao.pdf /nfs/classe/www/html/bmad/tutorial_bmad_tao.pdf`;
