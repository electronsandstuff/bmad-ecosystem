#!/usr/bin/env python

# Note: Run this script in the cpp_bmad_interface directory.

import re
import os

def searchit (file):

  re_int  = re.compile('INTEGER, *PARAMETER *:: *')
  re_real = re.compile('REAL\(RP\), *PARAMETER *:: *')
  re_a = re.compile('\[')
  re_d_exp = re.compile('\dD[+-]?\d')
  re_equal = re.compile('\=.*\dD[+-]?\d')

  params_here = False

  f_in = open(file)
  for line in f_in:
    line = line.partition('!')[0]   # Strip off comment
    line = line.upper()
    if '[' in line: continue                              # Skip parameter arrays

    if not re_int.match(line) and not re_real.match(line) and not params_here: continue

    line = re_int.sub('const int ', line)
    line = re_real.sub('const double ', line)

    line = line.replace('$', '')

    if re_equal.search(line):
      sub = re_d_exp.search(line).group(0).replace('D', 'E')   # Replace "3D6" with "3E6"
      line = re_d_exp.sub(sub, line)

    if '&' in line:
      line = line.replace('&', '')
      params_here = True
      line = '  ' + line.rstrip() + '\n'
    else:
      params_here = False
      line = '  ' + line.rstrip() + ';\n'

    f_out.write(line)

#---------------------------------------

if not os.path.exists('include'): os.makedirs('include')
f_out = open('include/bmad_enums.h', 'w')

f_out.write('''
#ifndef BMAD_ENUMS

namespace Bmad {
''')

searchit('../bmad/modules/bmad_struct.f90')
searchit('../bmad/modules/basic_bmad_mod.f90')
searchit('../sim_utils/io/output_mod.f90')
searchit('../sim_utils/interfaces/physical_constants.f90')

f_out.write('''
}

#define BMAD_ENUMS
#endif
''')

print 'Created: include/bmad_enums.h'

