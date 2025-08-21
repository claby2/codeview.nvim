if exists('g:loaded_codeview')
  finish
endif
let g:loaded_codeview = 1

lua require('codeview').setup()