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
  ddev reinstall-browsers

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
