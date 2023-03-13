add_llvm_component_library(LLVMTGXXXDesc
  TGXXXMCTargetDesc.cpp

  LINK_COMPONENTS
  MC
  Support
  TGXXXInfo

  ADD_TO_COMPONENT
  TGXXX
  )
