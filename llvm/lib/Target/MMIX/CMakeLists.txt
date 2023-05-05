add_llvm_component_group(MMIX)

add_llvm_target(
  MMIXCodeGen
  MMIXTargetMachine.cpp

  LINK_COMPONENTS
  Analysis
  AsmPrinter
  CodeGen
  Core
  MC
  MMIXDesc
  MMIXInfo
  SelectionDAG
  Support
  Target
  GlobalISel

  ADD_TO_COMPONENT
  MMIX
  )

#add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)