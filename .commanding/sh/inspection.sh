#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

detect_bin() {
  local name="${1:-}"
  command -v "$name" >/dev/null 2>&1 || return 1
  command -v "$name"
}

detect_project_root() {
  local root=""
  root="$(repo_root || true)"
  if [ -n "${root:-}" ]; then
    printf '%s' "$root"
    return 0
  fi

  if [ "$(basename "$COMMANDING_DIR")" = ".commanding" ]; then
    dirname "$COMMANDING_DIR"
    return 0
  fi

  printf '%s' "$COMMANDING_DIR"
}

PROJECT_ROOT="$(detect_project_root)"
LOG_DIR="$COMMANDING_DIR/logs/inspection"
TXT_DIR="$LOG_DIR/txt"
JSON_DIR="$LOG_DIR/json"
NDJSON_DIR="$LOG_DIR/ndjson"
TMP_DIR="$LOG_DIR/.tmp"
BASELINE_DIR="$LOG_DIR/baseline"
mkdir -p "$LOG_DIR" "$TXT_DIR" "$JSON_DIR" "$NDJSON_DIR" "$TMP_DIR" "$BASELINE_DIR"

TIMESTAMP="$(date '+%Y-%m-%d-%H-%M-%S')"
RUN_LOG="$LOG_DIR/inspection-$TIMESTAMP.log"
RUN_SUMMARY="$LOG_DIR/inspection-$TIMESTAMP.summary.txt"
RUN_SUMMARY_JSON="$LOG_DIR/inspection-$TIMESTAMP.summary.json"
RUN_NDJSON="$LOG_DIR/inspection-$TIMESTAMP.ndjson"
RUN_FINDINGS="$LOG_DIR/inspection-$TIMESTAMP.findings.ndjson"
RUN_CHAT="$LOG_DIR/inspection-$TIMESTAMP.chat.txt"
RUN_COMPARE="$LOG_DIR/inspection-$TIMESTAMP.compare.txt"
RUN_COMPARE_JSON="$LOG_DIR/inspection-$TIMESTAMP.compare.json"
RUN_FINDINGS_TSV="$TMP_DIR/findings-$TIMESTAMP.tsv"

RUN_SUMMARY_TXT_PATH="$TXT_DIR/inspection-$TIMESTAMP.summary.txt"
RUN_CHAT_TXT_PATH="$TXT_DIR/inspection-$TIMESTAMP.chat.txt"
RUN_COMPARE_TXT_PATH="$TXT_DIR/inspection-$TIMESTAMP.compare.txt"
RUN_SUMMARY_JSON_PATH="$JSON_DIR/inspection-$TIMESTAMP.summary.json"
RUN_COMPARE_JSON_PATH="$JSON_DIR/inspection-$TIMESTAMP.compare.json"
RUN_NDJSON_PATH="$NDJSON_DIR/inspection-$TIMESTAMP.ndjson"
RUN_FINDINGS_NDJSON_PATH="$NDJSON_DIR/inspection-$TIMESTAMP.findings.ndjson"

LATEST_LOG="$LOG_DIR/latest.log"
LATEST_SUMMARY="$LOG_DIR/latest.summary.txt"
LATEST_SUMMARY_JSON="$LOG_DIR/latest.summary.json"
LATEST_NDJSON="$LOG_DIR/latest.ndjson"
LATEST_FINDINGS="$LOG_DIR/latest.findings.ndjson"
LATEST_CHAT="$LOG_DIR/latest.chat.txt"
LATEST_COMPARE="$LOG_DIR/latest.compare.txt"
LATEST_COMPARE_JSON="$LOG_DIR/latest.compare.json"

LATEST_SUMMARY_TXT_PATH="$TXT_DIR/latest.summary.txt"
LATEST_CHAT_TXT_PATH="$TXT_DIR/latest.chat.txt"
LATEST_COMPARE_TXT_PATH="$TXT_DIR/latest.compare.txt"
LATEST_SUMMARY_JSON_PATH="$JSON_DIR/latest.summary.json"
LATEST_COMPARE_JSON_PATH="$JSON_DIR/latest.compare.json"
LATEST_NDJSON_PATH="$NDJSON_DIR/latest.ndjson"
LATEST_FINDINGS_NDJSON_PATH="$NDJSON_DIR/latest.findings.ndjson"

PREVIOUS_FINDINGS="$LOG_DIR/previous.findings.tsv"
BASELINE_FINDINGS="$BASELINE_DIR/active.findings.tsv"
BASELINE_SUMMARY_JSON="$BASELINE_DIR/active.summary.json"
BASELINE_CHAT="$BASELINE_DIR/active.chat.txt"

MANAGED_MARKER="Managed by Commanding inspection"
UNRESOLVED_PACKAGES="|"
VENDOR_AUTOLOAD_STATUS=""
VENDOR_AUTOLOAD_DETAIL=""
VENDOR_INTEGRITY_REPORTED=0

STATUS_OK=0
STATUS_WARN=0
STATUS_FAIL=0

PHP_BIN="$(detect_bin php || true)"
COMPOSER_BIN="$(detect_bin composer || true)"

TOOLS=(
  "php-cs-fixer|friendsofphp/php-cs-fixer|vendor/bin/php-cs-fixer|.php-cs-fixer.dist.php|style|medium"
  "phpstan|phpstan/phpstan|vendor/bin/phpstan|phpstan.neon.dist|typing|high"
  "rector|rector/rector|vendor/bin/rector|rector.php|quality|medium"
  "deptrac|deptrac/deptrac|vendor/bin/deptrac|deptrac.yaml|architecture|high"
)

EXTRA_PACKAGES=(
  "phpstan/phpstan-symfony"
  "phpstan/phpstan-doctrine"
)

log_line() {
  local line="${1:-}"
  printf '%s\n' "$line" | tee -a "$RUN_LOG" >/dev/null
}

summary_line() {
  local line="${1:-}"
  printf '%s\n' "$line" >> "$RUN_SUMMARY"
}

sanitize_field() {
  printf '%s' "${1:-}" | tr '\n\r\t|' '    '
}

add_finding() {
  local name status category severity risk action detail
  name="$(sanitize_field "${1:-}")"
  status="$(sanitize_field "${2:-}")"
  category="$(sanitize_field "${3:-}")"
  severity="$(sanitize_field "${4:-}")"
  risk="$(sanitize_field "${5:-}")"
  action="$(sanitize_field "${6:-}")"
  detail="$(sanitize_field "${7:-}")"

  printf '%s|%s|%s|%s|%s|%s|%s\n' \
    "$name" "$status" "$category" "$severity" "$risk" "$action" "$detail" >> "$RUN_FINDINGS_TSV"

  case "$status" in
    ok) STATUS_OK=$((STATUS_OK + 1)) ;;
    warn) STATUS_WARN=$((STATUS_WARN + 1)) ;;
    fail) STATUS_FAIL=$((STATUS_FAIL + 1)) ;;
  esac
}

ensure_parent_dir() {
  local path="${1:-}"
  mkdir -p "$(dirname "$path")"
}

write_managed_file() {
  local path="${1:-}"
  local mode="${2:-create}"
  local temp_file
  temp_file="$(mktemp)"
  cat > "$temp_file"

  ensure_parent_dir "$path"

  if [ -f "$path" ]; then
    if grep -q "$MANAGED_MARKER" "$path"; then
      cp "$temp_file" "$path"
      add_finding "$mode managed file" ok config low low "keep managed config current" "$path"
    else
      add_finding "preserve custom file" ok config low low "custom config preserved" "$path"
    fi
  else
    cp "$temp_file" "$path"
    add_finding "create config file" ok config low low "config created" "$path"
  fi

  rm -f "$temp_file"
}

has_composer_package() {
  local package_name="${1:-}"
  [ -n "$package_name" ] || return 1
  [ -f "$PROJECT_ROOT/composer.json" ] || return 1
  [ -n "$PHP_BIN" ] || return 1

  "$PHP_BIN" -r '
    $file = $argv[1];
    $pkg = $argv[2];
    if (!is_file($file)) { exit(1); }
    $data = json_decode(file_get_contents($file), true);
    if (!is_array($data)) { exit(2); }
    $req = [];
    if (isset($data["require"]) && is_array($data["require"])) {
        $req += $data["require"];
    }
    if (isset($data["require-dev"]) && is_array($data["require-dev"])) {
        $req += $data["require-dev"];
    }
    exit(array_key_exists($pkg, $req) ? 0 : 3);
  ' "$PROJECT_ROOT/composer.json" "$package_name" >/dev/null 2>&1
}

has_composer_script() {
  local script_name="${1:-}"
  [ -f "$PROJECT_ROOT/composer.json" ] || return 1
  [ -n "$PHP_BIN" ] || return 1

  "$PHP_BIN" -r '
    $file = $argv[1];
    $script = $argv[2];
    if (!is_file($file)) { exit(1); }
    $data = json_decode(file_get_contents($file), true);
    if (!is_array($data)) { exit(2); }
    if (!isset($data["scripts"]) || !is_array($data["scripts"])) { exit(3); }
    exit(array_key_exists($script, $data["scripts"]) ? 0 : 4);
  ' "$PROJECT_ROOT/composer.json" "$script_name" >/dev/null 2>&1
}

tool_binary_exists() {
  local rel_path="${1:-}"
  [ -n "$rel_path" ] || return 1
  [ -f "$PROJECT_ROOT/$rel_path" ]
}

tool_config_exists() {
  local rel_path="${1:-}"
  [ -n "$rel_path" ] || return 1
  [ -f "$PROJECT_ROOT/$rel_path" ]
}

tool_package_name() {
  local tool_name="${1:-}"
  local spec name package
  for spec in "${TOOLS[@]}"; do
    IFS='|' read -r name package _ _ _ _ <<< "$spec"
    if [ "$name" = "$tool_name" ]; then
      printf "%s" "$package"
      return 0
    fi
  done
  return 1
}

package_mark_unresolved() {
  local package_name="${1:-}"
  [ -n "$package_name" ] || return 0
  case "$UNRESOLVED_PACKAGES" in
    *"|$package_name|"*) ;;
    *) UNRESOLVED_PACKAGES="${UNRESOLVED_PACKAGES}${package_name}|" ;;
  esac
}

package_is_unresolved() {
  local package_name="${1:-}"
  [ -n "$package_name" ] || return 1
  case "$UNRESOLVED_PACKAGES" in
    *"|$package_name|"*) return 0 ;;
    *) return 1 ;;
  esac
}

composer_install_if_needed() {
  [ -f "$PROJECT_ROOT/composer.json" ] || return 0
  [ -n "$COMPOSER_BIN" ] || return 0

  if [ -f "$PROJECT_ROOT/vendor/autoload.php" ]; then
    VENDOR_AUTOLOAD_STATUS=""
    VENDOR_AUTOLOAD_DETAIL=""
    check_vendor_autoload_integrity
    if [ "$VENDOR_AUTOLOAD_STATUS" = "broken" ]; then
      add_finding "composer install preflight" warn tooling high medium "run composer install --no-plugins or restore vendor" "$VENDOR_AUTOLOAD_DETAIL"
    else
      add_finding "composer install preflight" ok tooling low low "vendor stack already present" "vendor/autoload.php found"
    fi
    return 0
  fi

  log_line "Running composer install preflight in $PROJECT_ROOT"
  if (
    cd "$PROJECT_ROOT"
    "$COMPOSER_BIN" install --no-plugins --no-interaction --no-progress
  ) >> "$RUN_LOG" 2>&1; then
    if [ -f "$PROJECT_ROOT/vendor/autoload.php" ]; then
      add_finding "composer install preflight" ok tooling medium low "install vendor stack before inspection" "composer install"
    else
      add_finding "composer install preflight" warn tooling high medium "run composer install manually" "composer install finished without vendor/autoload.php"
    fi
  else
    if [ -f "$PROJECT_ROOT/vendor/autoload.php" ]; then
      add_finding "composer install preflight" ok tooling low low "vendor stack already present" "composer install failed but vendor/autoload.php exists"
    else
      add_finding "composer install preflight" warn tooling high medium "run composer install manually" "composer install failed"
    fi
  fi
}

bootstrap_packages() {
  [ -f "$PROJECT_ROOT/composer.json" ] || {
    add_finding "bootstrap packages" warn tooling medium low "run inside PHP component root with composer.json" "$PROJECT_ROOT/composer.json missing"
    return 0
  }

  [ -n "$COMPOSER_BIN" ] || {
    add_finding "bootstrap packages" warn tooling high medium "install composer" "composer not found"
    return 0
  }

  composer_install_if_needed

  local missing=()
  local spec name package rel_tool
  for spec in "${TOOLS[@]}"; do
    IFS='|' read -r name package rel_tool _ _ _ <<< "$spec"
    if ! has_composer_package "$package" || ! tool_binary_exists "$rel_tool"; then
      missing+=("$package")
    fi
  done

  local extra
  for extra in "${EXTRA_PACKAGES[@]}"; do
    if ! has_composer_package "$extra"; then
      missing+=("$extra")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    add_finding "bootstrap packages" ok tooling low low "all canonical inspectors present" "none missing"
    return 0
  fi

  # deduplicate
  local unique_missing=()
  local seen="|"
  local item
  for item in "${missing[@]}"; do
    case "$seen" in
      *"|$item|"*) ;;
      *)
        unique_missing+=("$item")
        seen="${seen}${item}|"
        ;;
    esac
  done

  log_line "Installing missing dev packages in $PROJECT_ROOT: ${unique_missing[*]}"
  if (
    cd "$PROJECT_ROOT"
    "$COMPOSER_BIN" require --dev --no-plugins --no-interaction --no-progress "${unique_missing[@]}"
  ) >> "$RUN_LOG" 2>&1; then
    local unresolved=()
    for spec in "${TOOLS[@]}"; do
      IFS='|' read -r _ package rel_tool _ _ _ <<< "$spec"
      for item in "${unique_missing[@]}"; do
        [ "$item" = "$package" ] || continue
        if ! has_composer_package "$package" || ! tool_binary_exists "$rel_tool"; then
          unresolved+=("$package")
          package_mark_unresolved "$package"
        fi
      done
    done
    for item in "${EXTRA_PACKAGES[@]}"; do
      for extra in "${unique_missing[@]}"; do
        [ "$extra" = "$item" ] || continue
        if ! has_composer_package "$item"; then
          unresolved+=("$item")
          package_mark_unresolved "$item"
        fi
      done
    done

    if [ "${#unresolved[@]}" -eq 0 ]; then
      add_finding "bootstrap packages" ok tooling medium low "install missing dev packages" "${unique_missing[*]}"
    else
      add_finding "bootstrap packages" warn tooling high medium "review unresolved packages after composer require" "${unresolved[*]}"
    fi
  else
    for item in "${unique_missing[@]}"; do
      package_mark_unresolved "$item"
    done
    add_finding "bootstrap packages" warn tooling high medium "run composer require manually" "${unique_missing[*]}"
  fi
}

bootstrap_configs() {
  write_managed_file "$PROJECT_ROOT/phpstan.neon.dist" repair <<'EOF'
# Managed by Commanding inspection
includes:
    - vendor/phpstan/phpstan-symfony/extension.neon
    - vendor/phpstan/phpstan-symfony/rules.neon
    - vendor/phpstan/phpstan-doctrine/extension.neon
    - vendor/phpstan/phpstan-doctrine/rules.neon

parameters:
    level: 8
    paths:
        - src
        - tests

    tmpDir: var/phpstan

    excludePaths:
        analyse:
            - var/*
            - vendor/*
            - public/*
            - migrations/*
            - tests/Fixture/*
            - tests/Fixtures/*

    symfony:
        containerXmlPath: var/cache/dev/App_KernelDevDebugContainer.xml
        consoleApplicationLoader: tests/console-application.php

    doctrine:
        objectManagerLoader: tests/object-manager.php

    scanDirectories:
        - var/cache/dev/Symfony/Config

    scanFiles:
        - vendor/symfony/dependency-injection/Loader/Configurator/ContainerConfigurator.php

    checkMissingIterableValueType: true
    checkGenericClassInNonGenericObjectType: true
    reportUnmatchedIgnoredErrors: true
EOF

  write_managed_file "$PROJECT_ROOT/rector.php" repair <<'EOF'
<?php

declare(strict_types=1);

// Managed by Commanding inspection

use Rector\Config\RectorConfig;

return RectorConfig::configure()
    ->withPaths([
        __DIR__ . '/src',
        __DIR__ . '/tests',
    ])
    ->withPreparedSets(
        deadCode: true,
        codeQuality: true,
    )
    ->withComposerBased(
        symfony: true,
        doctrine: true,
        phpunit: true,
    )
    ->withSkip([
        __DIR__ . '/var/*',
        __DIR__ . '/vendor/*',
        __DIR__ . '/public/*',
        __DIR__ . '/migrations/*',
        __DIR__ . '/tests/Fixture/*',
        __DIR__ . '/tests/Fixtures/*',
    ])
    ->withCache(__DIR__ . '/var/rector');
EOF

  write_managed_file "$PROJECT_ROOT/.php-cs-fixer.dist.php" repair <<'EOF'
<?php

declare(strict_types=1);

// Managed by Commanding inspection

use PhpCsFixer\Config;
use PhpCsFixer\Finder;
use PhpCsFixer\Runner\Parallel\ParallelConfigFactory;

$finder = Finder::create()
    ->in([
        __DIR__ . '/src',
        __DIR__ . '/tests',
        __DIR__ . '/config',
    ])
    ->exclude([
        'var',
        'vendor',
        'public',
        'migrations',
    ])
    ->name('*.php');

return (new Config())
    ->setParallelConfig(ParallelConfigFactory::detect())
    ->setUsingCache(true)
    ->setCacheFile(__DIR__ . '/var/.php-cs-fixer.cache')
    ->setRules([
        '@PSR12' => true,
        'array_syntax' => ['syntax' => 'short'],
        'binary_operator_spaces' => ['default' => 'single_space'],
        'blank_line_after_opening_tag' => true,
        'declare_strict_types' => true,
        'line_ending' => true,
        'no_closing_tag' => true,
        'no_unused_imports' => true,
        'ordered_imports' => ['sort_algorithm' => 'alpha'],
        'single_import_per_statement' => true,
        'single_quote' => true,
        'trailing_comma_in_multiline' => [
            'elements' => ['arrays', 'arguments', 'parameters'],
        ],
    ])
    ->setFinder($finder);
EOF

  write_managed_file "$PROJECT_ROOT/deptrac.yaml" repair <<'EOF'
# Managed by Commanding inspection
deptrac:
  paths:
    - ./src

  exclude_files:
    - '#.*Test.*#'
    - '#.*Kernel.php#'

  layers:
    - name: Controller
      collectors:
        - type: className
          regex: '^App\\Controller\\.*'

    - name: Http
      collectors:
        - type: className
          regex: '^App\\(Request|Response|Dto|Command)\\.*'

    - name: ServiceInterface
      collectors:
        - type: className
          regex: '^App\\ServiceInterface\\.*'

    - name: Service
      collectors:
        - type: className
          regex: '^App\\Service\\.*'

    - name: RepositoryInterface
      collectors:
        - type: className
          regex: '^App\\RepositoryInterface\\.*'

    - name: Repository
      collectors:
        - type: className
          regex: '^App\\Repository\\.*'

    - name: Entity
      collectors:
        - type: className
          regex: '^App\\Entity\\.*'

    - name: InfrastructureInterface
      collectors:
        - type: className
          regex: '^App\\InfrastructureInterface\\.*'

    - name: Infrastructure
      collectors:
        - type: className
          regex: '^App\\Infrastructure\\.*'

  ruleset:
    Controller:
      - Http
      - Service
      - ServiceInterface

    Http:
      - Service
      - ServiceInterface

    Service:
      - ServiceInterface
      - RepositoryInterface
      - Entity
      - InfrastructureInterface

    Repository:
      - Entity

    Infrastructure:
      - InfrastructureInterface
      - Entity

    ServiceInterface: ~
    RepositoryInterface: ~
    InfrastructureInterface: ~
    Entity: ~
EOF

  write_managed_file "$PROJECT_ROOT/tests/object-manager.php" repair <<'EOF'
<?php

declare(strict_types=1);

// Managed by Commanding inspection

use App\Kernel;
use Symfony\Component\Dotenv\Dotenv;

require __DIR__ . '/../vendor/autoload.php';

if (class_exists(Dotenv::class) && file_exists(__DIR__ . '/../.env')) {
    (new Dotenv())->bootEnv(__DIR__ . '/../.env');
}

$_SERVER['APP_ENV'] ??= 'dev';
$_SERVER['APP_DEBUG'] ??= '1';

$kernel = new Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();

return $kernel->getContainer()->get('doctrine')->getManager();
EOF

  write_managed_file "$PROJECT_ROOT/tests/console-application.php" repair <<'EOF'
<?php

declare(strict_types=1);

// Managed by Commanding inspection

use App\Kernel;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Dotenv\Dotenv;

require __DIR__ . '/../vendor/autoload.php';

if (class_exists(Dotenv::class) && file_exists(__DIR__ . '/../.env')) {
    (new Dotenv())->bootEnv(__DIR__ . '/../.env');
}

$_SERVER['APP_ENV'] ??= 'dev';
$_SERVER['APP_DEBUG'] ??= '1';

$kernel = new Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);

return new Application($kernel);
EOF
}

add_composer_scripts_if_missing() {
  [ -f "$PROJECT_ROOT/composer.json" ] || {
    add_finding "composer scripts bootstrap" warn tooling medium low "composer.json missing" "$PROJECT_ROOT/composer.json"
    return 0
  }

  [ -n "$PHP_BIN" ] || {
    add_finding "composer scripts bootstrap" warn tooling medium medium "install php to edit composer.json safely" "php not found"
    return 0
  }

  local php_file result added conflicts
  php_file="$(mktemp)"
  cat > "$php_file" <<'PHP'
<?php
$file = $argv[1];
$map = [
  "qa:phpstan" => "php -d memory_limit=1G vendor/bin/phpstan analyse -c phpstan.neon.dist",
  "qa:rector" => "php vendor/bin/rector process --dry-run",
  "qa:deptrac" => "php vendor/bin/deptrac analyse --config-file=deptrac.yaml",
  "qa:cs" => "php vendor/bin/php-cs-fixer fix --dry-run --diff --config=.php-cs-fixer.dist.php",
  "qa" => [
    "@qa:phpstan",
    "@qa:deptrac",
    "@qa:rector",
  ],
  "inspection" => "bash ./.commanding/sh/inspection.sh full",
  "inspection:bootstrap" => "bash ./.commanding/sh/inspection.sh bootstrap",
  "inspection:run" => "bash ./.commanding/sh/inspection.sh run",
  "inspection:latest" => "bash ./.commanding/sh/inspection.sh latest",
  "inspection:chat" => "bash ./.commanding/sh/inspection.sh chat",
  "inspection:baseline" => "bash ./.commanding/sh/inspection.sh baseline",
  "inspection:compare" => "bash ./.commanding/sh/inspection.sh compare",
];
$data = json_decode(file_get_contents($file), true);
if (!is_array($data)) {
    fwrite(STDERR, "composer.json is not valid JSON\n");
    exit(2);
}
if (!isset($data["scripts"]) || !is_array($data["scripts"])) {
    $data["scripts"] = [];
}
$added = [];
$conflicts = [];
foreach ($map as $key => $value) {
    if (!array_key_exists($key, $data["scripts"])) {
        $data["scripts"][$key] = $value;
        $added[] = $key;
        continue;
    }
    if ($data["scripts"][$key] !== $value) {
        $conflicts[] = $key;
    }
}
file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);
echo json_encode(["added" => $added, "conflicts" => $conflicts], JSON_UNESCAPED_SLASHES), PHP_EOL;
PHP

  if ! result="$("$PHP_BIN" "$php_file" "$PROJECT_ROOT/composer.json" 2>>"$RUN_LOG")"; then
    rm -f "$php_file"
    add_finding "composer scripts bootstrap" warn tooling medium medium "repair composer.json manually" "scripts update failed"
    return 0
  fi

  rm -f "$php_file"

  added="$("$PHP_BIN" -r '$x=json_decode(stream_get_contents(STDIN),true); echo implode(",", $x["added"] ?? []);' <<<"$result" 2>/dev/null || true)"
  conflicts="$("$PHP_BIN" -r '$x=json_decode(stream_get_contents(STDIN),true); echo implode(",", $x["conflicts"] ?? []);' <<<"$result" 2>/dev/null || true)"

  if [ -n "${added:-}" ]; then
    add_finding "composer scripts added" ok tooling low low "composer scripts ready" "$added"
  else
    add_finding "composer scripts added" ok tooling low low "no missing scripts" "none"
  fi

  if [ -n "${conflicts:-}" ]; then
    add_finding "composer script conflicts" warn tooling medium low "review existing script keys" "$conflicts"
  fi
}


vendor_autoload_depends_tool() {
  local name="${1:-}"
  case "$name" in
    phpstan|rector|deptrac) return 0 ;;
    *) return 1 ;;
  esac
}

check_vendor_autoload_integrity() {
  if [ -n "$VENDOR_AUTOLOAD_STATUS" ]; then
    return 0
  fi

  if [ ! -f "$PROJECT_ROOT/composer.json" ]; then
    VENDOR_AUTOLOAD_STATUS="na"
    VENDOR_AUTOLOAD_DETAIL="composer.json missing"
    return 0
  fi

  if [ ! -f "$PROJECT_ROOT/vendor/autoload.php" ]; then
    VENDOR_AUTOLOAD_STATUS="missing"
    VENDOR_AUTOLOAD_DETAIL="vendor/autoload.php missing"
    return 0
  fi

  if [ -z "${PHP_BIN:-}" ]; then
    VENDOR_AUTOLOAD_STATUS="unknown"
    VENDOR_AUTOLOAD_DETAIL="php not found"
    return 0
  fi

  if (
    cd "$PROJECT_ROOT"
    "$PHP_BIN" -r 'require $argv[1];' "vendor/autoload.php"
  ) >> "$RUN_LOG" 2>&1; then
    VENDOR_AUTOLOAD_STATUS="ok"
    VENDOR_AUTOLOAD_DETAIL="vendor/autoload.php is loadable"
  else
    VENDOR_AUTOLOAD_STATUS="broken"
    VENDOR_AUTOLOAD_DETAIL="vendor/autoload.php cannot be required"
  fi

  return 0
}

report_vendor_autoload_integrity_if_needed() {
  check_vendor_autoload_integrity

  if [ "$VENDOR_INTEGRITY_REPORTED" -eq 1 ]; then
    return 0
  fi

  case "$VENDOR_AUTOLOAD_STATUS" in
    broken)
      add_finding "vendor autoload integrity" warn tooling high medium "run composer install --no-plugins or restore missing vendor files" "$VENDOR_AUTOLOAD_DETAIL"
      VENDOR_INTEGRITY_REPORTED=1
      ;;
  esac

  return 0
}

warmup_cache() {
  if [ -z "${PHP_BIN:-}" ]; then
    add_finding "symfony cache warmup" warn runtime medium low "install php to run Symfony console" "php not found"
    return 0
  fi

  if [ ! -f "$PROJECT_ROOT/bin/console" ]; then
    add_finding "symfony cache warmup" ok runtime low low "skip cache warmup for package/component repo" "bin/console not found"
    return 0
  fi

  log_line "Running Symfony cache warmup in $PROJECT_ROOT"
  if (
    cd "$PROJECT_ROOT"
    "$PHP_BIN" bin/console cache:warmup --env=dev
  ) >> "$RUN_LOG" 2>&1; then
    add_finding "symfony cache warmup" ok runtime low low "cache warmed" "bin/console cache:warmup --env=dev"
  else
    add_finding "symfony cache warmup" warn runtime medium low "review cache warmup output" "bin/console cache:warmup --env=dev"
  fi
}

ensure_stack_ready() {
  bootstrap_packages
  bootstrap_configs
  add_composer_scripts_if_missing
}

run_one_tool() {
  local name="${1:-}"
  local category="${2:-quality}"
  local severity="${3:-medium}"
  local rel_tool="${4:-}"
  local rel_config="${5:-}"
  local package_name=""
  local exit_code=0
  shift 5 || true

  package_name="$(tool_package_name "$name" || true)"

  if [ -z "${PHP_BIN:-}" ]; then
    add_finding "$name" warn tooling high medium "install php to run inspector" "php not found"
    return 0
  fi

  if ! tool_binary_exists "$rel_tool"; then
    if [ -n "$package_name" ] && package_is_unresolved "$package_name"; then
      add_finding "$name" ok tooling low low "tool skipped until package bootstrap succeeds" "$rel_tool missing after bootstrap"
    else
      add_finding "$name" warn tooling high medium "bootstrap inspector stack" "$rel_tool missing"
    fi
    return 0
  fi

  if [ -n "$rel_config" ] && ! tool_config_exists "$rel_config"; then
    add_finding "$name" warn tooling medium low "bootstrap inspection config" "$rel_config missing"
    return 0
  fi

  if vendor_autoload_depends_tool "$name"; then
    check_vendor_autoload_integrity
    if [ "$VENDOR_AUTOLOAD_STATUS" = "broken" ]; then
      report_vendor_autoload_integrity_if_needed
      add_finding "$name" ok tooling low low "tool skipped until vendor autoload integrity is restored" "$VENDOR_AUTOLOAD_DETAIL"
      return 0
    fi
  fi

  log_line "Running $name in $PROJECT_ROOT"
  if (
    cd "$PROJECT_ROOT"
    "$PHP_BIN" "$rel_tool" "$@"
  ) >> "$RUN_LOG" 2>&1; then
    add_finding "$name" ok "$category" low low "no action required" "passed"
    return 0
  else
    exit_code=$?
  fi

  if [ "$name" = "php-cs-fixer" ]; then
    case "$exit_code" in
      8)
        add_finding "$name" warn "$category" "$severity" low "review php-cs-fixer diff and apply fixes" "files need fixing (dry-run exit 8)"
        return 0
        ;;
      12)
        add_finding "$name" warn "$category" "$severity" medium "review php-cs-fixer diff and invalid syntax output" "invalid syntax and files need fixing"
        return 0
        ;;
    esac
  fi

  add_finding "$name" fail "$category" "$severity" medium "review $name output and fix findings" "failed"
  return 0
}

sync_format_artifacts() {
  cp "$RUN_SUMMARY" "$RUN_SUMMARY_TXT_PATH" 2>/dev/null || true
  cp "$RUN_CHAT" "$RUN_CHAT_TXT_PATH" 2>/dev/null || true
  cp "$RUN_COMPARE" "$RUN_COMPARE_TXT_PATH" 2>/dev/null || true
  cp "$RUN_SUMMARY_JSON" "$RUN_SUMMARY_JSON_PATH" 2>/dev/null || true
  cp "$RUN_COMPARE_JSON" "$RUN_COMPARE_JSON_PATH" 2>/dev/null || true
  cp "$RUN_NDJSON" "$RUN_NDJSON_PATH" 2>/dev/null || true
  cp "$RUN_FINDINGS" "$RUN_FINDINGS_NDJSON_PATH" 2>/dev/null || true

  cp "$LATEST_SUMMARY" "$LATEST_SUMMARY_TXT_PATH" 2>/dev/null || true
  cp "$LATEST_CHAT" "$LATEST_CHAT_TXT_PATH" 2>/dev/null || true
  cp "$LATEST_COMPARE" "$LATEST_COMPARE_TXT_PATH" 2>/dev/null || true
  cp "$LATEST_SUMMARY_JSON" "$LATEST_SUMMARY_JSON_PATH" 2>/dev/null || true
  cp "$LATEST_COMPARE_JSON" "$LATEST_COMPARE_JSON_PATH" 2>/dev/null || true
  cp "$LATEST_NDJSON" "$LATEST_NDJSON_PATH" 2>/dev/null || true
  cp "$LATEST_FINDINGS" "$LATEST_FINDINGS_NDJSON_PATH" 2>/dev/null || true
}

copy_latest_to_previous() {
  [ -f "$LATEST_FINDINGS" ] || return 0
  cp "$LATEST_FINDINGS" "$PREVIOUS_FINDINGS.ndjson" 2>/dev/null || true
  if [ -n "${PHP_BIN:-}" ]; then
    "$PHP_BIN" -r '
      $in = $argv[1];
      $out = $argv[2];
      if (!is_file($in)) exit(0);
      $rows = file($in, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
      $w = fopen($out, "w");
      foreach ($rows as $row) {
          $x = json_decode($row, true);
          if (!is_array($x)) continue;
          $line = implode("|", [
              str_replace("|", " ", (string)($x["name"] ?? "")),
              str_replace("|", " ", (string)($x["status"] ?? "")),
              str_replace("|", " ", (string)($x["category"] ?? "")),
              str_replace("|", " ", (string)($x["severity"] ?? "")),
              str_replace("|", " ", (string)($x["risk"] ?? "")),
              str_replace("|", " ", (string)($x["action"] ?? "")),
              str_replace("|", " ", (string)($x["detail"] ?? "")),
          ]);
          fwrite($w, $line . "\n");
      }
      fclose($w);
    ' "$LATEST_FINDINGS" "$PREVIOUS_FINDINGS" >/dev/null 2>&1 || true
  fi
}

render_outputs() {
  local total_findings overall_status dominant_risk
  total_findings=$((STATUS_OK + STATUS_WARN + STATUS_FAIL))

  if [ "$STATUS_FAIL" -gt 0 ]; then
    overall_status="attention"
    dominant_risk="medium"
  elif [ "$STATUS_WARN" -gt 0 ]; then
    overall_status="watch"
    dominant_risk="low"
  else
    overall_status="green"
    dominant_risk="low"
  fi

  summary_line "inspection_status=$overall_status"
  summary_line "verdict=collect-only"
  summary_line "dominant_risk=$dominant_risk"
  summary_line "ok=$STATUS_OK"
  summary_line "warn=$STATUS_WARN"
  summary_line "fail=$STATUS_FAIL"
  summary_line "findings=$total_findings"

  if [ -n "${PHP_BIN:-}" ]; then
    "$PHP_BIN" -r '
      $in = $argv[1];
      $summary = $argv[2];
      $ndjson = $argv[3];
      $json = $argv[4];
      $chat = $argv[5];
      $status = $argv[6];
      $risk = $argv[7];
      $findingsFile = $argv[8];
      $latestLog = $argv[9];
      $latestSummary = $argv[10];
      $latestJson = $argv[11];
      $latestFindings = $argv[12];

      $rows = file($in, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
      $findings = [];
      $statusCount = ["ok" => 0, "warn" => 0, "fail" => 0];
      $severityCount = [];
      $categoryCount = [];
      $severityRank = ["critical" => 4, "high" => 3, "medium" => 2, "low" => 1];
      $dominantSeverity = "low";
      $dominantSeverityScore = 0;

      foreach ($rows as $row) {
          $parts = explode("|", $row);
          $parts = array_pad($parts, 7, "");
          [$name, $state, $category, $severity, $riskLevel, $action, $detail] = $parts;

          $item = [
              "name" => $name,
              "status" => $state,
              "category" => $category,
              "severity" => $severity,
              "risk" => $riskLevel,
              "action" => $action,
              "detail" => $detail,
          ];

          $findings[] = $item;

          if (isset($statusCount[$state])) {
              $statusCount[$state]++;
          }

          $severityCount[$severity] = ($severityCount[$severity] ?? 0) + 1;
          $categoryCount[$category] = ($categoryCount[$category] ?? 0) + 1;

          $score = $severityRank[$severity] ?? 0;
          if ($score > $dominantSeverityScore) {
              $dominantSeverityScore = $score;
              $dominantSeverity = $severity;
          }
      }

      $ndjsonLines = [];
      foreach ($findings as $item) {
          $ndjsonLines[] = json_encode($item, JSON_UNESCAPED_SLASHES);
      }

      $payload = implode("\n", $ndjsonLines);
      if ($payload !== "") {
          $payload .= PHP_EOL;
      }

      file_put_contents($findingsFile, $payload);
      file_put_contents($ndjson, $payload);

      $summaryData = [
          "inspection_status" => $status,
          "verdict" => "collect-only",
          "dominant_risk" => $risk,
          "dominant_severity" => $dominantSeverity,
          "scoreboard" => $statusCount,
          "severity" => $severityCount,
          "category" => $categoryCount,
          "findings" => count($findings),
          "artifact" => [
              "log" => $latestLog,
              "summary" => $latestSummary,
              "json" => $latestJson,
              "findings" => $latestFindings,
          ],
      ];
      file_put_contents($json, json_encode($summaryData, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);

      $chatLines = [];
      $chatLines[] = "Inspection report";
      $chatLines[] = "mode: collect";
      $chatLines[] = "verdict: collect-only";
      $chatLines[] = "dominant severity: " . $dominantSeverity;
      $chatLines[] = "dominant risk: " . $risk;
      $chatLines[] = "findings: " . count($findings);
      $chatLines[] = "fail: " . ($statusCount["fail"] ?? 0) . " | warn: " . ($statusCount["warn"] ?? 0);
      $chatLines[] = "";
      $chatLines[] = "Top categories";
      foreach ($categoryCount as $key => $value) {
          $chatLines[] = " - " . $key . ": " . $value;
      }
      $chatLines[] = "";
      $chatLines[] = "Normalized findings";
      foreach ($findings as $item) {
          $chatLines[] = " - [" . $item["status"] . "][" . $item["category"] . "][" . $item["severity"] . "/" . $item["risk"] . "] " . $item["name"] . " :: " . $item["action"] . " :: " . $item["detail"];
      }
      $chatLines[] = "";
      $chatLines[] = "Artifact";
      $chatLines[] = " - log: " . $latestLog;
      $chatLines[] = " - summary: " . $latestSummary;
      $chatLines[] = " - json: " . $latestJson;
      $chatLines[] = " - findings: " . $latestFindings;
      file_put_contents($chat, implode("\n", $chatLines) . "\n");
    ' "$RUN_FINDINGS_TSV" "$RUN_SUMMARY" "$RUN_NDJSON" "$RUN_SUMMARY_JSON" "$RUN_CHAT" "$overall_status" "$dominant_risk" "$RUN_FINDINGS" "$LATEST_LOG" "$LATEST_SUMMARY" "$LATEST_SUMMARY_JSON" "$LATEST_FINDINGS" >> "$RUN_LOG" 2>&1
  else
    cp "$RUN_SUMMARY" "$RUN_CHAT"
    : > "$RUN_SUMMARY_JSON"
    : > "$RUN_NDJSON"
    : > "$RUN_FINDINGS"
  fi

  cp "$RUN_LOG" "$LATEST_LOG"
  cp "$RUN_SUMMARY" "$LATEST_SUMMARY"
  cp "$RUN_SUMMARY_JSON" "$LATEST_SUMMARY_JSON" 2>/dev/null || true
  cp "$RUN_NDJSON" "$LATEST_NDJSON" 2>/dev/null || true
  cp "$RUN_FINDINGS" "$LATEST_FINDINGS" 2>/dev/null || true
  cp "$RUN_CHAT" "$LATEST_CHAT" 2>/dev/null || true
  sync_format_artifacts
}

normalize_compare_file() {
  local in_file="${1:-}"
  local out_file="${2:-}"

  [ -f "$in_file" ] || {
    : > "$out_file"
    return 0
  }

  tr -d '
' < "$in_file" | sed '/^[[:space:]]*$/d' | LC_ALL=C sort -u > "$out_file"
}

compare_findings() {
  local source_label compare_tsv
  source_label="none"

  if [ -f "$BASELINE_FINDINGS" ]; then
    compare_tsv="$BASELINE_FINDINGS"
    source_label="baseline"
  elif [ -f "$PREVIOUS_FINDINGS" ]; then
    compare_tsv="$PREVIOUS_FINDINGS"
    source_label="previous"
  else
    printf '%s\n' "No baseline or previous findings available." > "$RUN_COMPARE"
    printf '%s\n' '{ "compare_source": "none", "introduced_count": 0, "resolved_count": 0 }' > "$RUN_COMPARE_JSON"
    cp "$RUN_COMPARE" "$LATEST_COMPARE"
    cp "$RUN_COMPARE_JSON" "$LATEST_COMPARE_JSON"
    sync_format_artifacts
    return 0
  fi

  local introduced resolved
  introduced="$(mktemp)"
  resolved="$(mktemp)"

  normalize_compare_file "$RUN_FINDINGS_TSV" "$TMP_DIR/current.compare.tsv"
  normalize_compare_file "$compare_tsv" "$TMP_DIR/source.compare.tsv"

  comm -23 "$TMP_DIR/current.compare.tsv" "$TMP_DIR/source.compare.tsv" > "$introduced"
  comm -13 "$TMP_DIR/current.compare.tsv" "$TMP_DIR/source.compare.tsv" > "$resolved"

  {
    printf '%s\n' "Inspection compare"
    printf '%s\n' "source: $source_label"
    printf '%s\n' ""
    printf '%s\n' "introduced:"
    if [ -s "$introduced" ]; then
      sed 's/^/- /' "$introduced"
    else
      printf '%s\n' "- none"
    fi
    printf '%s\n' ""
    printf '%s\n' "resolved:"
    if [ -s "$resolved" ]; then
      sed 's/^/- /' "$resolved"
    else
      printf '%s\n' "- none"
    fi
  } > "$RUN_COMPARE"

  if [ -n "${PHP_BIN:-}" ]; then
    "$PHP_BIN" -r '
      $source = $argv[1];
      $introduced = is_file($argv[2]) ? array_values(array_filter(array_map("trim", file($argv[2])))) : [];
      $resolved = is_file($argv[3]) ? array_values(array_filter(array_map("trim", file($argv[3])))) : [];
      $data = [
          "compare_source" => $source,
          "introduced_count" => count($introduced),
          "resolved_count" => count($resolved),
          "introduced" => $introduced,
          "resolved" => $resolved,
      ];
      file_put_contents($argv[4], json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);
    ' "$source_label" "$introduced" "$resolved" "$RUN_COMPARE_JSON" >> "$RUN_LOG" 2>&1 || true
  else
    printf '{ "compare_source": "%s" }\n' "$source_label" > "$RUN_COMPARE_JSON"
  fi

  cp "$RUN_COMPARE" "$LATEST_COMPARE"
  cp "$RUN_COMPARE_JSON" "$LATEST_COMPARE_JSON"
  sync_format_artifacts

  rm -f "$introduced" "$resolved"
}

set_baseline() {
  if [ ! -f "$LATEST_FINDINGS" ] || [ ! -f "$LATEST_SUMMARY_JSON" ]; then
    printf '%s\n' "No latest inspection artifacts found. Run inspection first."
    return 0
  fi

  cp "$LATEST_FINDINGS" "$BASELINE_DIR/active.findings.ndjson"
  cp "$LATEST_SUMMARY_JSON" "$BASELINE_SUMMARY_JSON"
  [ -f "$LATEST_CHAT" ] && cp "$LATEST_CHAT" "$BASELINE_CHAT" || true

  if [ -n "${PHP_BIN:-}" ]; then
    "$PHP_BIN" -r '
      $in = $argv[1];
      $out = $argv[2];
      $rows = file($in, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
      $w = fopen($out, "w");
      foreach ($rows as $row) {
          $x = json_decode($row, true);
          if (!is_array($x)) continue;
          $line = implode("|", [
              str_replace("|", " ", (string)($x["name"] ?? "")),
              str_replace("|", " ", (string)($x["status"] ?? "")),
              str_replace("|", " ", (string)($x["category"] ?? "")),
              str_replace("|", " ", (string)($x["severity"] ?? "")),
              str_replace("|", " ", (string)($x["risk"] ?? "")),
              str_replace("|", " ", (string)($x["action"] ?? "")),
              str_replace("|", " ", (string)($x["detail"] ?? "")),
          ]);
          fwrite($w, $line . "\n");
      }
      fclose($w);
    ' "$LATEST_FINDINGS" "$BASELINE_FINDINGS" >/dev/null 2>&1 || true
  fi

  printf '%s\n' "Baseline updated:"
  printf '%s\n' " - $BASELINE_SUMMARY_JSON"
  printf '%s\n' " - $BASELINE_FINDINGS"
}

bootstrap_only() {
  : > "$RUN_LOG"
  : > "$RUN_SUMMARY"
  : > "$RUN_FINDINGS_TSV"

  log_line "Inspection bootstrap started"
  ensure_stack_ready
  render_outputs
  compare_findings

  printf '%s\n' "Bootstrap completed."
  printf '%s\n' "Latest summary: $LATEST_SUMMARY"
}

run_tool_suite() {
  warmup_cache
  run_one_tool "php-cs-fixer" style medium "vendor/bin/php-cs-fixer" ".php-cs-fixer.dist.php" fix --dry-run --diff --config=.php-cs-fixer.dist.php
  run_one_tool "phpstan" typing high "vendor/bin/phpstan" "phpstan.neon.dist" analyse -c phpstan.neon.dist
  run_one_tool "rector" quality medium "vendor/bin/rector" "rector.php" process --dry-run
  run_one_tool "deptrac" architecture high "vendor/bin/deptrac" "deptrac.yaml" analyse --config-file=deptrac.yaml
}

run_only() {
  : > "$RUN_LOG"
  : > "$RUN_SUMMARY"
  : > "$RUN_FINDINGS_TSV"

  copy_latest_to_previous

  log_line "Inspection run started"
  ensure_stack_ready
  run_tool_suite
  render_outputs
  compare_findings

  printf '%s\n' "Inspection completed."
  printf '%s\n' "Latest chat report: $LATEST_CHAT"
  printf '%s\n' "Latest compare report: $LATEST_COMPARE"
}

full_run() {
  : > "$RUN_LOG"
  : > "$RUN_SUMMARY"
  : > "$RUN_FINDINGS_TSV"

  copy_latest_to_previous

  log_line "Inspection full started"
  ensure_stack_ready
  run_tool_suite
  render_outputs
  compare_findings

  printf '%s\n' "Inspection full completed."
  printf '%s\n' "Latest summary: $LATEST_SUMMARY"
  printf '%s\n' "Latest chat report: $LATEST_CHAT"
  printf '%s\n' "Latest compare report: $LATEST_COMPARE"
}

show_latest() {
  if [ -f "$LATEST_SUMMARY" ]; then
    cat "$LATEST_SUMMARY"
    printf '\n'
    printf '%s\n' "chat: $LATEST_CHAT"
    printf '%s\n' "compare: $LATEST_COMPARE"
  else
    printf '%s\n' "No latest inspection summary found."
  fi
}

show_chat() {
  if [ -f "$LATEST_CHAT" ]; then
    cat "$LATEST_CHAT"
  else
    printf '%s\n' "No latest chat report found."
  fi
}

compare_latest_now() {
  if [ ! -f "$LATEST_FINDINGS" ]; then
    printf '%s\n' "No latest inspection findings found."
    return 0
  fi

  if [ -n "${PHP_BIN:-}" ]; then
    "$PHP_BIN" -r '
      $in = $argv[1];
      $out = $argv[2];
      $rows = file($in, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
      $w = fopen($out, "w");
      foreach ($rows as $row) {
          $x = json_decode($row, true);
          if (!is_array($x)) continue;
          $line = implode("|", [
              str_replace("|", " ", (string)($x["name"] ?? "")),
              str_replace("|", " ", (string)($x["status"] ?? "")),
              str_replace("|", " ", (string)($x["category"] ?? "")),
              str_replace("|", " ", (string)($x["severity"] ?? "")),
              str_replace("|", " ", (string)($x["risk"] ?? "")),
              str_replace("|", " ", (string)($x["action"] ?? "")),
              str_replace("|", " ", (string)($x["detail"] ?? "")),
          ]);
          fwrite($w, $line . "\n");
      }
      fclose($w);
    ' "$LATEST_FINDINGS" "$RUN_FINDINGS_TSV" >/dev/null 2>&1 || true
  else
    cp "$LATEST_FINDINGS" "$RUN_FINDINGS_TSV" 2>/dev/null || true
  fi

  : > "$RUN_LOG"
  compare_findings
}

show_compare() {
  compare_latest_now >/dev/null 2>&1 || true

  if [ -f "$LATEST_COMPARE" ]; then
    cat "$LATEST_COMPARE"
  else
    printf '%s\n' "No compare report found."
  fi
}

menu() {
  ui_clear
  ui_banner "Inspection"

  printf '%s\n' "Inspection Menu"
  printf '%s\n' "---------------"
  printf '%s\n' "1) Bootstrap inspector stack"
  printf '%s\n' "2) Run inspection"
  printf '%s\n' "3) Full (bootstrap + run)"
  printf '%s\n' "4) Latest summary"
  printf '%s\n' "5) Latest chat report"
  printf '%s\n' "6) Set baseline from latest"
  printf '%s\n' "7) Compare latest"
  printf '%s\n' "Space) Exit"

  read -r -n 1 -s -p "Choice: " action
  printf '\n'

  case "${action:-}" in
    1) bootstrap_only ;;
    2) run_only ;;
    3) full_run ;;
    4) show_latest ;;
    5) show_chat ;;
    6) set_baseline ;;
    7) show_compare ;;
    *) exit 0 ;;
  esac
}

main() {
  local cmd="${1:-menu}"
  shift || true

  case "$cmd" in
    bootstrap) bootstrap_only ;;
    run|collect|soft) run_only ;;
    full|inspection) full_run ;;
    latest) show_latest ;;
    chat) show_chat ;;
    baseline) set_baseline ;;
    compare) show_compare ;;
    menu) menu ;;
    *)
      printf '%s\n' "Unknown inspection command: $cmd"
      exit 0
      ;;
  esac

  exit 0
}

main "$@"
