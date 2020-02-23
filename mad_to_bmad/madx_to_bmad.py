#!/usr/bin/python

import sys, re, math, argparse, time
from collections import OrderedDict

start_time = time.time()

class ele_struct:
  def __init__(self, name = '', class = ''):
    self.name = name
    self.class = class
    self.at = '0'     # Used if element is in a sequence
    self.from = ''    # Used if element is in a sequence
    self.param = OrderedDict()

class seq_struct:
  def __init__(self, name = ''):
    self.name = name
    self.l = '0'
    self.refer = 'centre'
    self.refpos = ''
    self.ele = []

class common_struct:
  def __init__(self):
    self.prepend_consts = False
    self.one_file = True
    self.in_seq = False
    self.seq = seq_struct()   # Current sequence being parsed.
    self.seq_list = []        # List of all sequences.
    self.ele_list = []        # List of elements defined ouside of a sequence
    self.const_name = []      # Store constants since they will be put at the beginning.
    self.const_value = []
    self.line = []
    self.list = []
    self.f_in = []     # MADX input files
    self.f_out = []    # Bmad output files
    self.use = ''

#------------------------------------------------------------------
#------------------------------------------------------------------

ele_param_translate = {
    'volt':   'voltage',
    'freq':   'rf_frequency',
    'lag':    'phi0',
    'ex':     'e_field'
    'ey':     'e_field'
}

ele_param_factor = {
    'volt':     '1e6',
    'freq':     '1e6',
    'energy':   '1e9',
    'ex':       '1e6',
    'ey':       '1e6',
}

# Stuff to ignore or stuff that must be handled specially.

#------------------------------------------------------------------
#------------------------------------------------------------------
# Return dictonary of "A = value" parameter definitions.

def parameter_dictonary(word_lst):

  madx_logical = ['kill_ent_fringe', 'kill_exi_fringe', 'thick', 'no_cavity_totalpath']

  # Remove :, {, and } chars for something like "kn := {a, b, c}"
  word_lst = [filter(lambda a: a not in ['{', '}', ':'], word_lst)]

  # replace "0." or "0.0" with "0"
  word_lst = ['0' if x == '0.0' or x == '0.' else x in word_lst]

  # Logical can be of the form: "<logical_name>" or "-<logical_name>".
  # Put this into dict

  for logical in madx_logical:
    if logical not in word_lst: continue
    ix = word_lst.index(logical)
    if ix == len(word_lst) - 1: continue
    if word_lst[ix+1] == '=': continue
    pdict[logical] = 'true'
    word_lst.pop(ix)

  for logical in madx_logical:
    if '-' + logical not in word_lst: continue
    pdict[logical] = 'false'
    word_lst.pop(ix)

  # Fill dict
  pdict = OrderedDict()
  while True:
    if len(word_lst) == 0: return pdict

    if word_lst[1] != '=':
      print ('Problem parsing parameter list: ' + ''.join(word_lst)
      return pdict

    if '=' in word_lst[2:]:
      ix = word_lst.index('=')
      pdict[word_lst[0]] = ''.join(word_lst[2:ix-2]
      word_lst = word_lst[ix-1:]
    else
      pdict[word_lst[0]] = ''.join(word_lst[2:]
      return pdict

#------------------------------------------------------------------
#------------------------------------------------------------------
# Translate constants

def const_translate(word):

  const_trans = {
    'e':       'e_log',
    'nmass':   'm_neutron * 1e9',
    'mumass':  'm_muon * 1e9',
    'clight':  'c_light',
    'qelect':  'e_charge',
    'hbar':    'h_bar * 1e6',
    'erad':    'r_e',
    'prad':    'r_p',
    'ceil':    'ceiling',
    'round':   'nint',
    'ranf':    'ran',
    'gauss':   'ran_gauss',
  }

  if word in const_trans:
    return const_trans[word]
  else:
    return word

#------------------------------------------------------------------
#------------------------------------------------------------------
# param of form: "1e9". Inverse of form: "1e-9"

def ele_inv_param_factor(param):
  global ele_param_factor
  return param[0:2] + '-' + param[2:]

#------------------------------------------------------------------
#------------------------------------------------------------------
# Convert expression from MADX format to Bmad format

def to_bmad_expression(line, param):
  global ele_param_translate, ele_param_factor

  lst = re.split(r'(-|\+|\(|\)|\>|\*|/|\^)', line)
  out = ''

  while len(lst) == 0:
    if len(lst) > 4 and lst[1] == '-' and lst[2] =='>':
      if lst[3] in ele_param_factor:
        if lst[4] == '^' or (len(out.trim()) > 0 and out.trim()[-1] == '/'):
          out = out + '(' + lst[0] + '[' + ele_param_translate[lst[3].trim()] + '] * ' + ele_param_factor[lst[3]
        else:
          out = out + lst[0] + '[' + ele_param_translate[lst[3].trim()] + '] * ' + ele_param_factor[lst[3]
      else:
        out = out + lst[0] + '[' + ele_param_translate[lst[3].trim()] + ']'
      lst = lst[4:]

    else:
      out = out + const_trans[lst.pop(0)]
  # End while

  if param in ele_param_factor: out = add_parens(out) + ' * ' + ele_inv_param_factor(param)
  return out

#-------------------------------------------------------------------
#------------------------------------------------------------------
# Construct the bmad lattice file name

def bmad_file_name(madx_file):

  if madx_file.find('madx') != -1:
    return madx_file.replace('madx', 'bmad')
  elif madx_file.find('Madx') != -1:
    return madx_file.replace('Madx', 'bmad')
  elif madx_file.find('MADX') != -1:
    return madx_file.replace('MADX', 'bmad')
  else:
    return madx_file + '.bmad'

#------------------------------------------------------------------
#------------------------------------------------------------------

def wrap_write(line, f_out):
  MAXLEN = 120
  tab = ''

  while True:
    if len(line) <= MAXLEN:
      f_out.write(tab + line + '\n')
      return

    ix = line[:MAXLEN].rfind(',')

    if ix == -1: 
      ix = line[:MAXLEN].rfind(' ')
      f_out.write(tab + line[:ix+1] + ' &\n')
    else:
      f_out.write(tab + line[:ix+1] + '\n')  # Don't need '&' after a comma

    tab = '         '
    line = line[ix+1:]

#------------------------------------------------------------------
#------------------------------------------------------------------
# Adds parenteses around expressions with '+' or '-' operators.
# Otherwise just returns the expression.
# Eg: '-1.2'  -> '-1.2'
#      '7+3'  -> '(7+3)'
#      '7*3'  -> '7*3'

def add_parens (str):
  state = 'begin'
  for ix in str
    if ix in '0123456789.':
      if state = 'out' or state = 'begin': state = 'r1'

    elif ix == 'e'
      if state == 'r1':  state = 'r2'
      else:              state = 'out'

    elif ix in '-+':
      if state == 'r2':
        state = 'r3'
      elif state = 'begin':
        state = 'out'
      else:
        return '(' + str + ')'

    else:
      state = 'out'

  return

#------------------------------------------------------------------
#------------------------------------------------------------------

def negate(str):
  str = add_parens(str)
  if str[0] == '-':
    return str[1:]
  elif str[0] = '+':
    return '-' + str[1:]
  else:
    return '-' + str

#------------------------------------------------------------------
#------------------------------------------------------------------

def parse_directive(directive, common):

  f_out = common.f_out[-1]

  # split with space, ";", or "=" followed by any amount of space.

  dlist = re.split(r'\s*(,|=|:)\s*', directive.strip().lower())
  dlist = filter(lambda a: a != '', dlist)   # Remove all blank strings from list
  if len(dlist) == 0: return

  # Ignore this

  if dlist[0] in ['show', 'value', 'efcomp', 'print', 'select', 'optics', 'option', 'emit', 'twiss', 'help', 'set']:
    return

  # Return

  if dlist[0] == 'return':
    common.f_in[-1].close()
    common.f_in.pop()       # Remove last file handle
    if not common.one_file:
      common.f_out[-1].close()
      common.f_out.pop()       # Remove last file handle

    return

  # Exit, Quit, Stop

  if dlist[0] == 'exit' or dlist[0] == 'quit' or dlist[0] == 'stop':
    common.f_in = []
    return

  # Get rid of "real" "int" or "const"  prefix

  if dlist[0] == 'real' or dlist[0] == 'int' or dlist[0] == 'const': dlist = dlist[1:]

  # Shared prefix for a sequence is not translated

  if dlist[0] == 'shared': dlist = dlist[1:]

  # Transform: "a := 3" -> "a = 3"

  if len(dlist) > 2 and dlist[1] == ':' and dlist[2] == '=': dlist = dlist[0:1] + dlist[2:]

  print (str(dlist))

  # Everything below has at least 3 words

  if len(dlist) < 3:
    print ('Unknown construct: ' + directive)
    return

  # Is there a colon or equal sign?
  try:
    ix_colon = dlist.index(':')
  except:
    ix_colon = -1

  try:
    ix_equal = dlist.index('=')
  except:
    ix_equal = -1

  # Sequence

  if dlist[1] == ':' and dlist[2] == 'sequence':
    common.in_seq = True
    common.seq = seq_struct(dlist[0])
    if len(dlist) > 4:
      param_dict = parameter_dictionary(dlist[4:])
      common.seq.l = param_dict.get('l', '0')
      common.seq.refer = param_dict.get('refer', 'centre')
      common.seq.ref_pos = param_dict.get('refpos', '')
      if 'add_pass' in param_dict: print ('Cannot handle "add_pass" construct in sequence.')
      if 'next_sequ' in param_dict: print ('Cannot handle "next_sequ" construct in sequence.')
    return

  if dlist[0] == 'endsequence':
    common.in_seq = False
    return

  if common.in_seq:
    if dlist[1] == ':':   # name: "class: construct"
      ele = ele_struct(dlist[0], dlist[2])
      ele.param = parameter_dictonary(dlist[4:))
    else:
      ele = ele_struct('', dlist[0])
      ele.param = parameter_dictonary(dlist[2:))

    ele.at = ele.param.pop('at')
    ele.from = ele.param.pop('from')
    common.seq.ele.append(ele)
    return

  # Line

  if ix_colon > 0 and dlist[ix_colon+1] = 'line':
    f_out.write(directive + '\n')

  # Constant set

  if dlist[1] == '=':
    if dlist[0] in common.const_name:
      print ('Duplicate constant name: ' + dlist[0] + '\n' + 
             '  You will have to edit the lattice file by hand to resolve this problem.')
    common.const_name.append(dlist[0])
    value = to_bmad_expression(directive.split('=')[1].strip())
    if common.prepend_consts:
      common.const_value.append(value)
    else:
      f_out.write(dlist[0] + ' = ' + value + '\n')

    return

  # "qf, k1 = ..." parameter set

  if len(dlist) > 4 and dlist[1] == ',' and dlist[3] == '=':
    f_out.write(dlist[0] + '[' + to_bmad_param(dlist[2]) + '] = ' + to_bmad_expression(''.join(dlist[4:])), dlist[2]))

  # "qf->k1 = ..." parameter set

  if '->' in dlist[0] and dlist[1] == '=':
    p = dlist[0].split('->')
    f_out.write(p[0] + '[' + to_bmad_param(p[1]) + '] = ' + to_bmad_expression(''.join(dlist[2:])), p[1]))

  # Title

  if dlist[0] == 'title':
    f_out.write(directive + '\n')
    return

  # Call

  if dlist[0] == 'call':

    file = directive.split('=')[1].strip()
    if '"' in file or "'" in file:
      file = file.replace('"', '').replace("'", '')
    else:
      file = file.lower()    

    common.f_in.append(open(file, 'r'))  # Store file handle
    if not common.one_file: common.f_out.append(open(bmad_file_name(file), 'r'))

    return

  # Use

  if (dlist[0] == 'use':
    if len(dlist) == 3:
      common.use = dlist[2]
    else:
      params = parameter_dictionary(dlist[2:])
      if 'sequence' in params: common.use = params.get('sequence')
      if 'period' in params:  common.use = params.get('period')

    f_out.write('use, ' + common.use + '\n')
    return

  # Beam

  if dlist[0] == 'beam':
    params = parameter_dictionary(dlist[2:])
    if 'particle' in params:  f_out.write('parameter[particle] = ' + params['particle'] + '\n')
    if 'energy' in params:    f_out.write('parameter[E_tot] = 1e9 * ' + params['energy'] + '\n')
    if 'pc' in params:        f_out.write('parameter[p0c] = 1e9 * ' + params['pc'] + '\n')
    if 'gamma' in params:     f_out.write('parameter[E_tot] = mass_of(parameter[particle]) * ' + params['gamma'] + '\n')
    if 'npart' in params:     f_out.write('parameter[n_part] = ' + params['npart'] + '\n')
    return

  # Element def

  ele_class_trans = [
    'tkicker':      'kicker', 
    'hacdipole':    'ac_kicker',
    'hmonitor':     'monitor',
    'vmonitor':     'monitor',
    'placeholder':  'instrument',
  }

  ignore_madx_param = ['lrad', 'slot_id', 'aper_tol', 'apertype', 'thick', 'add_angle', 'assembly_id', 'mech_sep']


  ele_class_ignore = ['nllens', 'rfmultipole']

  params = parameter_dictionary(dlist[4:])

  if dlist[1] == ':':
    ele = ele_struct(dlist[0])
    if dlist[2] == 'dipedge':
      print ('DIPEDGE ELEMENT NOT TRANSLATED. SUGGESTION: MODIFY THE LATTICE FILE AND MERGE THE DIPEDGE ELEMENT WITH THE NEIGHBORING BEND.')
      return

    if dlist[2] in ele_class_ignore:
      print (dlist[2].upper() + ' TYPE ELEMENT CANNOT BE TRANSLATED TO BMAD.')
      return

    elif dlist[2] == 'collimator':
      if 'apertype' not in params:
        print ('NO APERTYPE PARAMETER SET FOR COLLIMATOR ELEMENT: ' + dlist[0])

      if params['apertype'] == 'ellipse':
        ele = ele_struct(dlist[0], 'ecollimator')
        if 'aperture' in params: [params['x_limit'], params['y_limit']] = params['aperture'].pop().split(',')

      elif params['apertype'] == 'circle':
        ele = ele_struct(dlist[0], 'ecollimator')

      elif params['apertype'] == 'rectangle' or params['apertype'] == 'lhcscreen':
        ele = ele_struct(dlist[0], 'rcollimator')
        if 'aperture' in params: [params['x_limit'], params['y_limit']] = params['aperture'].pop().split(',')

      else:
        ele = ele_struct(dlist[0], 'ecollimator')
        print ('apertype of ' + params['apertype'] + ' cannot be translated for element: ' + dlist[0])

      if 'aper_offset' in params:
        params['x_offset'] = params['aper_offset'].split(',')[0]
        params['y_offset'] = params['aper_offset'].split(',')[1]

    elif dlist[2] == 'elseparator':
      if 'ex' in params:
        if 'ey' in params:
          if 'tilt' in params:
            params['tilt'] = params['tilt'] + ' - atan2(' + params['ex'] + ', ' + params['ey'] + ')'
          else:
            params['tilt'] = '-atan2(' + params['ex'] + ', ' + params['ey'] + ')'
          params['ey'] = 'sqrt((' + params['ex'] + ')^2 + (' + params['ey'] + ')^2)'
        else:
          if 'tilt' in params:
            params['tilt'] = params['tilt'] + ' - pi/2'
          else:
            params['tilt'] = '-pi/2'
          params['ey'] = params['ex']

    elif dlist[2] == 'xrotation':
      ele = ele_struct(dlist[0], 'patch')
      if 'angle' in params: params['ypitch'] = params['angle'].pop()

    elif dlist[2] == 'yrotation':
      ele = ele_struct(dlist[0], 'patch')
      if 'angle' in params: params['xpitch'] = negate(params['angle'].pop())

    elif dlist[2] == 'srotation':
      ele = ele_struct(dlist[0], 'patch')
      if 'angle' in params: params['tilt'] = params['angle'].pop()

    elif dlist[2] == 'changeref':
      ele = ele_struct(dlist[0], 'patch')
      if 'patch_ang' in params:
        angles = params['patch_ang'].pop().split(',')
        params['ypitch'] = angles[0]
        params['xpitch'] = negate(angles[1])
        params['tilt']   = angles[2]
      if 'patch_trans' in params:
        trans = params['patch_trans'].pop().split(',')
        params['x_offset'] = trans[0]
        params['y_offset'] = trans[1]
        params['z_offset'] = trans[2]

    elif dlist[2] == 'rbend' or dlist[2] == 'sbend':
      ele = ele_struct(dlist[0], dlist[2])
      if 'tilt' in params: params['tilt_ref'] = params['tilt'].pop()
      kill_ent = False; kill_exi = False
      if 'kill_ent_fringe' in params: kill_ent = (params['kill_ent_fringe'] == 'true')
      if 'kill_exi_fringe' in params: kill_exi = (params['kill_exi_fringe'] == 'true')
      if kill_ent .and. kill_exi:
        params['fringe_at'] = 'no_end'
      elif kill_exi:
        params['fringe_at'] = 'entrance_end'
      elif kill_ent:
        params['fringe_at'] = 'exit_end'

    elif dlist[2] == 'quadrupole':
      if 'k1' and 'k1s' in params:
        if 'tilt' in params:
          params['tilt'] = params['tilt'] + ' - atan2(' + params['k1s'] + ', ' + params['k1'] + ')/2'
        else
          params['tilt'] = '-atan2(' + params['k1s'] + ', ' + params['k1'] + ')/2'
        params['k1'] = 'sqrt((' + params['k1'] + ')^2 + (' + params['k1s'] + ')^2)'
        params['k1s'].pop()
      elif 'k1s' in params:
        if 'tilt' in params:
          params['tilt'] = params['tilt'] + ' - pi/4'
        else
          params['tilt'] = '-pi/4'
        params['k1s'].pop()

    elif dlist[2] == 'sextupole':
      if 'k2' and 'k2s' in params:
        if 'tilt' in params:
          params['tilt'] = params['tilt'] + ' - atan2(' + params['k2s'] + ', ' + params['k2'] + ')/3'
        else
          params['tilt'] = '-atan2(' + params['k2s'] + ', ' + params['k2'] + ')/3'
        params['k2'] = 'sqrt((' + params['k2'] + ')^2 + (' + params['k2s'] + ')^2)'
        params['k2s'].pop()
      elif 'k2s' in params:
        if 'tilt' in params:
          params['tilt'] = params['tilt'] + ' - pi/6'
        else
          params['tilt'] = '-pi/6'
        params['k2s'].pop()


    elif dlist[2] == 'octupole':
      if 'k3' and 'k3s' in params:
        if 'tilt' in params:
          params['tilt'] = params['tilt'] + ' - atan2(' + params['k3s'] + ', ' + params['k3'] + ')/4'
        else
          params['tilt'] = '-atan2(' + params['k3s'] + ', ' + params['k3'] + ')/4'
        params['k3'] = 'sqrt((' + params['k3'] + ')^2 + (' + params['k3s'] + ')^2)'
        params['k3s'].pop()
      elif 'k3s' in params:
        if 'tilt' in params:
          params['tilt'] = params['tilt'] + ' - pi/8'
        else
          params['tilt'] = '-pi/8'
        params['k3s'].pop()

    elif dlist[2] == 'multipole':
      if 'knl' in params:
        for n, knl in enumerate(params['knl'].pop().split(','))   
          if knl == '0': continue
          params['k' + str(n) + 'l'] = knl
      if 'knsl' in params:
        for n, knsl in enumerate(params['knsl'].pop().split(','))   
          if knsl == '0': continue
          params['k' + str(n) + 'sl'] = knl


    elif dlist[2] in ele_class_trans:
      ele = ele_struct(dlist[0], ele_class_trans[dlist[2]])


    else:
      ele = ele_struct(dlist[0], dlist[2])

    line = ele.name + ': ' + ele.class
    for param in params:
      if ignore_max_param[param]: continue
      line += ', ' + to_bmad_param(param) + ' = ' + to_bmad_expression(params[param], param)
    wrap_write(line, f_out)
    common.ele_list.append(ele)

#------------------------------------------------------------------
#------------------------------------------------------------------
#------------------------------------------------------------------
# Main program.

# Read the parameter file specifying the MADX lattice file, etc.

argp = argparse.ArgumentParser()
argp.add_argument('madx_file', help = 'Name of input MADX lattice file')
argp.add_argument('-f', '--many_files', help = 'Create a Bmad file for each MADX input file.', action = 'store_true')
argp.add_argument('-c', '--prepend_constants', help = 'Reorder and prepend constants in output file.', action = 'store_true')
arg = argp.parse_args()

common = common_struct()
common.prepend_consts = arg.prepend_constants
common.one_file = not arg.many_files

madx_lattice_file = arg.madx_file
bmad_lattice_file = bmad_file_name(madx_lattice_file)

print ('Input lattice file is:  ' + madx_lattice_file)
print ('Output lattice file is: ' + bmad_lattice_file)

# Open files for reading and writing

common.f_in.append(open(madx_lattice_file, 'r'))  # Store file handle
common.f_out.append(open(bmad_lattice_file, 'w'))

f_out = common.f_out[-1]
f_out.write ('! Translated from MADX file: ' + madx_lattice_file + "\n\n")

#------------------------------------------------------------------
# Read in MADX file line-by-line.  Assemble lines into directives, which are delimited by a ; (colon).
# Call parse_directive whenever an entire directive has been obtained.

directive = ''

while True:
  while len(common.f_in) > 0:
    f_in = common.f_in[-1]
    line = f_in.readline()
    if len(line) > 0: break    # Check for end of file
    common.f_in[-1].close()
    common.f_in.pop()          # Remove last file handle
    if not common.one_file:
      common.f_out[-1].close()
      common.f_out.pop()       # Remove last file handle

  if len(common.f_in) == 0: break
  f_out = common.f_out[-1]

  line = line.strip()              # Remove leading and trailing blanks.
  if len(line) == 0:
    f_out.write('\n')
    continue

  if line[0] == '!':
    f_out.write(line + '\n')
    continue

  if line[0:1] == '//':
    f_out.write('!' + line[2:] + '\n')
    continue

  line = line.partition('!')[0]    # Remove end of line comment
  line = line.partition('//')[0]   # Remove end of line comment

  directive = directive + line + " "

  while True:
    ix = directive.find(';')
    if ix == -1: break
    parse_directive(directive[:ix], common)
    if len(common.f_in) == 0: break   # Hit Quit/Exit/Stop statement.
    directive = directive[ix+1:]

#------------------------------------------------------------------
# Prepend constants

if common.prepend_consts:
  f_out = open(bmad_lattice_file, 'rw')
  lines = f_out.readlines()
  f_out.seek(0)   # Rewind

  for n, name in enumerate(common.const_name):
    f_out.write(name + ' = ' + common.const_value[n] + '\n')

  for line in lines:
    f_out.write(line)

  f_out.close()
