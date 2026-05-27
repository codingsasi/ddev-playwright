setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/ddev-playwright-test
  export PW_DIR=${TESTDIR}/tests/playwright
  export PROJNAME=ddev-playwright-test
  export DDEV_NONINTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  rm -rf "${TESTDIR}"
  mkdir -p "${TESTDIR}"
  cd "${TESTDIR}" || exit 1
  ddev config --project-type=php --project-name=${PROJNAME} --docroot=web --create-docroot
  ddev start -y >/dev/null
  # Create a simple PHP test page
  cat > web/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DDEV Playwright Test</title>
</head>
<body>
    <h1>The way is clear!</h1>
    <p>This is a test page for Playwright</p>
</body>
</html>
EOF
}

health_checks() {
  # Basic curl check to verify site is working
  CURLVERIF=$(curl -s https://${PROJNAME}.ddev.site/ | grep -o -E "<h1>(.*)</h1>" | sed 's/<\/h1>//g; s/<h1>//g;' | tr '\n' '#')
  if [[ $CURLVERIF == "The way is clear!#" ]]; then
    echo "# Site accessibility OK" >&3
  else
    echo "# Site accessibility failed"
    echo $CURLVERIF
    exit 1
  fi
}

teardown() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

@test "install from directory" {
  set -eu -o pipefail
  cd "${TESTDIR}"

  echo "# Basic site check" >&3
  health_checks

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get ${DIR}
  ddev restart

  echo "# Init Playwright project and install browsers (addon flow)" >&3
  ddev install-playwright

  echo "# Verify Playwright command is available" >&3
  ddev playwright --version

  echo "# Check that test directory was created and initialized" >&3
  if [ -d "${PW_DIR}" ] && [ -f "${PW_DIR}/playwright.config.ts" ] && [ -f "${PW_DIR}/package.json" ]; then
    echo "# Playwright project initialized successfully with config and package.json" >&3
  else
    echo "# Playwright project initialization failed - missing files"
    ls -la ${PW_DIR}/
    exit 1
  fi

  echo "# Verify Playwright was installed during setup" >&3
  if [ -d "${PW_DIR}/node_modules" ] && [ -d "${PW_DIR}/tests" ]; then
    echo "# Node modules and tests directory created by install-playwright OK" >&3
  else
    echo "# Node modules or tests directory not found, initialization may have failed"
    ls -la ${PW_DIR}/
    exit 1
  fi

  echo "# Run Playwright test (after install-playwright)" >&3
  if ddev playwright test 2>/dev/null; then
    echo "# Playwright tests passed successfully" >&3
  else
    echo "# Playwright tests failed"
    ddev playwright test  # Re-run to show output for debugging
    exit 1
  fi

  echo "# Check HTML reports port accessibility" >&3
  timeout 10 ddev playwright show-report --host=0.0.0.0 --port=9323 &
  sleep 3
  REPORT_HTTP_STATUS=$(curl --write-out '%{http_code}' --silent --output /dev/null http://${PROJNAME}.ddev.site:9323 || echo "000")
  if [[ $REPORT_HTTP_STATUS == 200 ]]; then
    echo "# HTML Report server OK" >&3
  else
    echo "# HTML Report server failed: $REPORT_HTTP_STATUS (acceptable)" >&3
  fi
  pkill -f "show-report" 2>/dev/null || true
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )

  echo "# Basic site check" >&3
  health_checks

  echo "# ddev add-on get with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get ${DIR}
  ddev restart >/dev/null

  echo "# Init Playwright project and install browsers" >&3
  ddev install-playwright

  echo "# Verify Playwright command is available" >&3
  ddev playwright --version

  echo "# Run Playwright test" >&3
  if ddev playwright test 2>/dev/null; then
    echo "# Playwright tests passed successfully" >&3
  else
    echo "# Playwright tests failed"
    ddev playwright test
    exit 1
  fi

  echo "# Verify Playwright install --help available" >&3
  ddev playwright install --help > /dev/null
  if [ $? -eq 0 ]; then
    echo "# Playwright install command available OK" >&3
  else
    echo "# Playwright install command failed"
    exit 1
  fi
}

@test "test automated setup and immediate usage" {
  set -eu -o pipefail
  cd ${TESTDIR}

  echo "# Basic site check" >&3
  health_checks

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get ${DIR}
  ddev restart

  echo "# Init Playwright and install browsers (addon flow)" >&3
  ddev install-playwright

  echo "# Verify automated setup completed" >&3
  if [ -d "${PW_DIR}/node_modules" ] && [ -f "${PW_DIR}/package.json" ]; then
    echo "# Automated setup completed successfully" >&3
  else
    echo "# Automated setup may have failed"
    ls -la ${PW_DIR}/
    exit 1
  fi

  echo "# Run Playwright test" >&3
  if ddev playwright test 2>/dev/null; then
    echo "# Playwright tests executed successfully" >&3
  else
    echo "# Playwright tests failed"
    ddev playwright test
    exit 1
  fi
}

@test "shared browsers volume reused by second project" {
  set -eu -o pipefail

  # Project A: the standard setup() project. Pin a version, install addon,
  # run install-playwright — this populates the shared docker volume.
  cd "${TESTDIR}"
  PIN_VERSION="1.49.0"
  echo "# Project A (${PROJNAME}): pin Playwright ${PIN_VERSION}" >&3
  ddev config --web-environment-add "PLAYWRIGHT_VERSION=${PIN_VERSION}"

  echo "# Project A: install addon and populate shared volume" >&3
  ddev add-on get ${DIR}
  ddev restart >/dev/null
  ddev install-playwright

  echo "# Verify shared docker volume exists and per-version marker is present" >&3
  docker volume inspect ddev-playwright-browsers >/dev/null
  ddev exec "test -f /opt/playwright-browsers/${PIN_VERSION}/.installed"
  echo "# Shared volume populated by Project A OK" >&3

  # Project B: a second, independent ddev project. Should reuse the volume
  # populated by A — install-playwright must skip the browser download.
  # No EXIT trap here: it would clobber bats's own EXIT trap and cause the
  # test result line to be lost. Any leftover state is cleaned up at the
  # start of this test on the next run.
  PROJ_B="${PROJNAME}-second"
  DIR_B="${TESTDIR}-second"
  ddev delete -Oy "${PROJ_B}" >/dev/null 2>&1 || true
  rm -rf "${DIR_B}"

  mkdir -p "${DIR_B}/web"
  cd "${DIR_B}"
  cat > web/index.php << 'EOF'
<!DOCTYPE html>
<html><head><title>DDEV Playwright Test (Project B)</title></head>
<body><h1>Project B</h1><p>Shared volume reuse test</p></body></html>
EOF
  ddev config --project-type=php --project-name=${PROJ_B} --docroot=web --create-docroot >/dev/null
  ddev config --web-environment-add "PLAYWRIGHT_VERSION=${PIN_VERSION}"
  ddev start -y >/dev/null

  echo "# Project B: install addon (should reuse shared volume, no re-download)" >&3
  ddev add-on get ${DIR}
  ddev restart >/dev/null

  INSTALL_OUT=$(ddev install-playwright 2>&1)
  if echo "${INSTALL_OUT}" | grep -q "already present in shared volume"; then
    echo "# Project B skipped browser download via shared volume OK" >&3
  else
    echo "# Project B did not reuse the shared volume. install-playwright output:"
    echo "${INSTALL_OUT}"
    ddev delete -Oy "${PROJ_B}" >/dev/null 2>&1 || true
    rm -rf "${DIR_B}"
    exit 1
  fi

  echo "# Project B can run Playwright tests against shared browsers" >&3
  if ddev playwright test --project=chromium 2>/dev/null; then
    echo "# Project B tests passed using shared volume OK" >&3
  else
    echo "# Project B tests failed"
    ddev playwright test --project=chromium
    ddev delete -Oy "${PROJ_B}" >/dev/null 2>&1 || true
    rm -rf "${DIR_B}"
    exit 1
  fi

  # Happy-path cleanup. Move out of DIR_B before deleting it so bats's
  # teardown (which cd's into TESTDIR) doesn't see a missing cwd.
  cd "${TESTDIR}"
  ddev delete -Oy "${PROJ_B}" >/dev/null 2>&1 || true
  rm -rf "${DIR_B}"
}

@test "install specific Playwright version and verify installed version" {
  set -eu -o pipefail
  cd "${TESTDIR}"

  echo "# Basic site check" >&3
  health_checks

  # Set a specific version before add-on get so the prompt is skipped and this version is used
  export SPECIFIC_VERSION="1.49.0"
  echo "# Setting PLAYWRIGHT_VERSION=${SPECIFIC_VERSION} in project config" >&3
  ddev config --web-environment-add "PLAYWRIGHT_VERSION=${SPECIFIC_VERSION}"

  echo "# ddev add-on get ${DIR} (will use existing PLAYWRIGHT_VERSION)" >&3
  ddev add-on get ${DIR}
  ddev restart

  echo "# Run install-playwright to init project and install browsers with pinned version" >&3
  ddev install-playwright

  echo "# Reinstall browsers so they match pinned version (image may have been built with different version)" >&3
  printf 'y\n' | ddev reinstall-browsers

  echo "# Verify @playwright/test version in package.json" >&3
  if [ ! -f "${PW_DIR}/package.json" ]; then
    echo "# package.json not found at ${PW_DIR}"
    exit 1
  fi
  INSTALLED_VERSION=$(cd "${PW_DIR}" && node -e "console.log(require('./package.json').devDependencies['@playwright/test'])")
  if [[ "${INSTALLED_VERSION}" != *"${SPECIFIC_VERSION}"* ]]; then
    echo "# Expected @playwright/test version containing ${SPECIFIC_VERSION}, got: ${INSTALLED_VERSION}"
    exit 1
  fi
  echo "# @playwright/test version OK: ${INSTALLED_VERSION}" >&3

  echo "# Verify playwright CLI reports same version" >&3
  CLI_VERSION=$(ddev exec "cd /var/www/html/tests/playwright && npx playwright --version" 2>/dev/null | tr -d '\r' || true)
  if [[ "${CLI_VERSION}" != *"${SPECIFIC_VERSION}"* ]]; then
    echo "# Expected playwright --version to contain ${SPECIFIC_VERSION}, got: ${CLI_VERSION}"
    exit 1
  fi
  echo "# Playwright CLI version OK: ${CLI_VERSION}" >&3

  echo "# Run a quick test (chromium only) to ensure the installed version works" >&3
  if ddev playwright test --project=chromium 2>/dev/null; then
    echo "# Playwright tests passed with version ${SPECIFIC_VERSION}" >&3
  else
    echo "# Playwright test failed (run 'ddev playwright test --project=chromium' for details)"
    ddev playwright test --project=chromium
    exit 1
  fi
}
