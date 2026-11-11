include_guard(DIRECTORY)

# Tag v1 is one commit past the commit deps.lock holds.
import_dependency(locked::dep
  REPOSITORY "${LOCK_REPO}"
  TAG        v1
  SUBDIR     .
)
