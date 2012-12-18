
trimChars = (string, chars) ->
  s = string
  remove = (pattern) -> s = s.replace pattern, ''
  for char in chars
    remove new RegExp '^' + char
    remove new RegExp char + '$'
  s

exports.sanitize = (string) ->
  if string?
    trimChars string.trim(), [',', ';']
  else
    ''

exports.unique = (values) ->
  output = {}
  output[values[i]] = values[i] for i in [0...values.length]
  value for key, value of output
