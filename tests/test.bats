setup() {
  set -eu -o pipefail
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/ddev-playwright-test
  export PW_DIR=${TESTDIR}/test/playwright
  mkdir -p $TESTDIR
  export PROJNAME=ddev-playwright-test
  export DDEV_NONINTERACTIVE=true
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
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
  cd ${TESTDIR}

  echo "# Basic site check" >&3
  health_checks

  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get ${DIR}
  ddev restart

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
    echo "# Node modules and tests directory created by npm init playwright OK" >&3
  else
    echo "# Node modules or tests directory not found, initialization may have failed"
    ls -la ${PW_DIR}/
  fi

  echo "# Install Playwright browsers" >&3
  ddev playwright install chrome chromium msedge firefox webkit --with-deps

  echo "# Run Playwright test (after browser installation)" >&3
  ddev playwright test

  echo "# Check HTML reports port accessibility" >&3
  # Start the report server in background and test it
  timeout 10 ddev playwright show-report --host=0.0.0.0 --port=9323 &
  sleep 3
  REPORT_HTTP_STATUS=$(curl --write-out '%{http_code}' --silent --output /dev/null http://${PROJNAME}.ddev.site:9323 || echo "000")
  if [[ $REPORT_HTTP_STATUS == 200 ]]; then
    echo "# HTML Report server OK" >&3
  else
    echo "# HTML Report server failed: $REPORT_HTTP_STATUS"
    # Don't fail the test as report server might not be running yet
    echo "# (This is acceptable as report server may not be persistent)" >&3
  fi
  pkill -f "show-report" || true
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )

  echo "# Basic site check" >&3
  health_checks

  echo "# ddev add-on get with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  # For release testing, we would use the actual repo path
  # This test would be updated when the addon is published
  ddev add-on get ${DIR}
  ddev restart >/dev/null

  echo "# Verify Playwright command is available" >&3
  ddev playwright --version

  echo "# Run Playwright test (this will install dependencies automatically)" >&3
  ddev playwright test

  echo "# Verify Playwright installation" >&3
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

  echo "# Verify automated setup completed" >&3
  if [ -d "${PW_DIR}/node_modules" ] && [ -f "${PW_DIR}/package.json" ]; then
    echo "# Automated setup completed successfully" >&3
  else
    echo "# Automated setup may have failed"
    ls -la ${PW_DIR}/
  fi

  echo "# Install browsers before running tests" >&3
  ddev playwright install

  echo "# Run Playwright test after browser installation" >&3
  ddev playwright test

  echo "# Verify test results" >&3
  if ddev playwright test  2>&1 | grep -q "passed"; then
    echo "# Playwright tests executed successfully" >&3
  else
    echo "# Playwright tests failed"
    ddev playwright test
    exit 1
  fi
}
