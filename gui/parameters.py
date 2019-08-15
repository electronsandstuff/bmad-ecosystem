from collections import OrderedDict
import string

startup_list = [
  'beam_file;FILE;T;',
  'beam_all_file;FILE;T;',
  'beam_init_position_file;FILE;T;',
  'building_wall_file;FILE;T;',
  'data_file;FILE;T;',
  'hook_init_file;FILE;T;',
  'init_file;FILE;T;',
  'noinit;LOGIC;T;F',
  'lattice_file;FILE;T;',
  'plot_file;FILE;T;',
  'startup_file;FILE;T;',
  'var_file;FILE;T;',
  'slice_lattice;FILE;T;',
  'disable_smooth_line_calc;LOGIC;T;F',
  'log_startup;LOGIC;T;F',
  'no_stopping;LOGIC;T;F',
  'rf_on;LOGIC;T;F',
]

#-------------------------------------------------

class tao_parameter():

  def __init__(self, param_name, param_type, can_vary, param_value, sub_param=None):
    self.name = param_name
    self.type = param_type
    self.can_vary = (can_vary == 'T')
    self.is_ignored = (can_vary == 'I')
    self.sub_param = sub_param #associated sub_parameter (name)

    if param_type == 'STR':
      self.value = param_value
    elif param_type == 'FILE':
      self.value = param_value
    elif param_type in ['DAT_TYPE', 'DAT_TYPE_Z']:
      self.value = param_value
    elif param_type == 'INT':
      try:
        self.value = int(param_value)
      except:
        self.value = None
    elif param_type == 'REAL':
      try:
        self.value = float(param_value)
      except:
        self.value = None
    elif param_type == "REAL_ARR": #value: list of floats
      self.value = param_value
    elif param_type == 'LOGIC':
      self.value = (param_value == 'T')
    elif param_type == 'ENUM':
      self.value = param_value
    elif param_type == 'INUM':
      try:
        self.value = int(param_value)
      except:
        self.value = None
    elif param_type == 'STRUCT': #value: list of tao_parameters
      self.value = param_value
    else:
      print ('UNKNOWN PARAMETER TYPE: ' + param_type)

  def __str__(self):
    return str(self.value)

  def __repr__(self):
    return self.type + ';' + str(self.can_vary) + ';' + str(self.value)

# An item in the parameter list is a string that looks like:
#        'lattice_file;STR;T;bmad.lat'

def tao_parameter_dict(param_list):
    this_dict = OrderedDict()
    for param in param_list:
      v = param.split(';')
      this_dict[v[0]] = str_to_tao_param(param)
    return this_dict

def str_to_tao_param(param_str):
    '''
    Takes a parameter string
    ('lattice_file;STR;T;bmad.lat')
    and returns a tao_parameter
    '''
    v = param_str.split(';')
    sub_param = None #default
    #TEMPORARY FIX
    if (len(v[2]) == 2) & (len(v) == 3):
      v.append(v[2][1])
      v[2] = v[2][0]
    ###
    # Special case: REAL_ARR (unknown length)
    if v[1] == "REAL_ARR":
      arr = []
      for i in range(len(v[3:])):
        x = v[3:][i]
        try:
          arr.append(float(x))
        except:
          if i==len(v[3:])-1: #last item, could be a related parameter name
            if len(x) > 0:
              sub_param = x
          else:
            arr.append(float(0))
      v[3] = arr
    elif v[1] == 'STRUCT':
      n_comp = int(len(v[3:])/3)
      components = v[3:][:3*n_comp]
      c_list = [0]*n_comp
      for n in range(n_comp):
        c_name = components[3*n]
        c_type = components[3*n+1]
        c_val = components[3*n+2]
        c_list[n] = tao_parameter(c_name, c_type, v[2], c_val)
      v[3] = c_list
      if len(v[3:]) % 3 == 1: # one more item than expected --> it is a sub_param
        sub_param = v[-1]
    # Generic case sub_param: name;type;can_vary;value;sub_param
    if len(v) == 5:
      sub_param=v[4]
    return tao_parameter(v[0],v[1],v[2],v[3], sub_param)

#-------------------------------------------------
param_dict = tao_parameter_dict(startup_list)
