file(READ ${TOP_DIRECTORY}/src/CurrentBuild.txt CurrentBuild)

string(REGEX MATCH "VERSION_MAJOR ([0-9]+)" temp ${CurrentBuild})
string(REGEX REPLACE "VERSION_MAJOR ([0-9]+)" "\\1" CurrentBuild_MAJOR ${temp})
string(REGEX MATCH "VERSION_MINOR ([0-9]+)" temp ${CurrentBuild})
string(REGEX REPLACE "VERSION_MINOR ([0-9]+)" "\\1" CurrentBuild_MINOR ${temp})
string(REGEX MATCH "VERSION_BUILD ([0-9]+)" temp ${CurrentBuild})
string(REGEX REPLACE "VERSION_BUILD ([0-9]+)" "\\1" CurrentBuild_BUILD ${temp})

set(CurrentBuild_VERSION "${CurrentBuild_MAJOR}.${CurrentBuild_MINOR}.${CurrentBuild_BUILD}")