---
date:
  created: 2025-04-13
---

# Forget About Python Reqs Install Time in CI 
The speed of `uv` combined with GitLab CI/CD cache enables near-instantaneous 
installation of Python requirements compared to `pip`. Stop helping entropy rise in your CI/CD.

Here, I’ll show a simple example of using native `uv` package management in your pipeline.
You can easily adapt the same approach for `uv pip` or even `pip` itself.

<!-- more -->

## Introduction
Usage of `uv`, which is not the new kid on the block anymore package manager for Python, 
enables significantly faster installation of Python packages with the ability to use
`pip` compatible commands (and also `pipx`). It is also superb for different Python
versions and environments management.

And in your docker files you can install it without `pip` or `curl` calls, just a simple
`COPY` command to deliver the `uv` binary:

```dockerfile
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
```

## Caveats of uv
Before using `uv`, you should be aware of some of its by-default quirks:

- python installations come from 
  [Python Standalone Builds project](https://github.com/astral-sh/python-build-standalone), 
  you can read more on this project's quirks [here](https://gregoryszorc.com/docs/python-build-standalone/main/quirks.html),
  but I can't see any particular issues with it for most of the use cases;
- python packages are not "compiled" to bytecode, so you need to run `uv` with `--compile` flag,
  [uv docs on compiling bytecode](https://docs.astral.sh/uv/reference/settings/#compile-bytecode)
  if you want to have marginally faster startup time of your Python application;
- `uv` "installs" packages by linking them to the `site-packages` directory of your Python
  environment, [uv docs on link-mode](https://docs.astral.sh/uv/reference/settings/#link-mode)

## Usage in CI/CD
When you are using `uv` in your local development flow and you have "warmed" cache with
all the packages you need, you can install them in a matter of seconds. (For the sake of
`pip` appreciation it also works significantly faster with the "warmed" cache). But in
your CI/CD pipeline with multiple jobs and single-use environments spinning up and down
you need to download and install all the packages every time. And when it comes to
machine learning environments and data science projects, your resulting `site-packages`
ends up quite large.

This is where GitLab CI/CD cache comes in. 

### GitLab CI/CD cache
With GitLab CI/CD cache, you can cache the downloaded packages 
by caching-the-cache of the `uv` and sharing it between jobs.
It should work out-of-the-box with the single custom runner, but you may also use it
with the distributed runners caching. More on the GitLab CI/CD cache in the 
[GitLab docs](https://docs.gitlab.com/ee/ci/caching/).

## Hands-on example
Here is a simple example of how to use `uv` with GitLab CI/CD cache for good:

```yaml

variables:
  PYTHON_VERSION: 3.12
  BASE_LAYER: bookworm-slim
  # It's always a good idea to have at least some certainty about the
  # version of the package manager you are using
  UV_VERSION: 0.6
  # GitLab CI creates a separate mountpoint for the build directory,
  # so we need to copy instead of using hard links.
  UV_LINK_MODE: copy
  # This will set the cache directory for uv by the environment variable
  # and this environment variable will be used across all the jobs
  UV_CACHE_DIR: .uv_cache

# Example of jobs using uv cache
stages:
  - cache
  - lint
  - test

# Helpers
.base_cache_cfg: &base_cache_cfg
  key:
    files:
      - uv.lock
  paths:
    - $UV_CACHE_DIR
  
.with_uv_cache: &with_uv_cache
  # You may not want to use the specified image, here it is just an example
  image: ghcr.io/astral-sh/uv:$UV_VERSION-python$PYTHON_VERSION-$BASE_LAYER
  # This way it will install packages with versions exactly matching the lock file
  # or in case of no lock file it will prepare the new one and install packages
  before_script:
    - uv sync --frozen || uv sync
    - uv cache prune --ci
  cache:
    <<: *base_cache_cfg
    # This sets the cache policy to pull the cache before the job if present
    # and push cache contents after the job if it was modified
    policy: pull-push

.with_uv_cache_pull:
  extends: .with_uv_cache
  cache:
    <<: *base_cache_cfg
    # This sets the cache policy to pull, so it will be pulled from the cache
    # before the job and not pushed to the cache after the job finishes
    policy: pull
  

prepare uv cache:
  stage: cache
  extends: .with_uv_cache
  script:
    - echo "uv cache is ready"

ruff check:
  stage: lint
  extends: .with_uv_cache_pull
  script:
    - uv run ruff check

ruff format:
  stage: lint
  extends: .with_uv_cache_pull
  script:
    - uv run ruff format --check

test:
  stage: test
  extends: .with_uv_cache_pull
  script:
    - uv run pytest -sv
```


## Conclusion
With the above example you can easily set up your GitLab CI/CD pipeline to use `uv` with
GitLab CI/CD cache. It will significantly speed up the installation of Python packages
in your Python-related jobs. You can also adapt the same approach with `pip` or even `poetry`.

## Useful links
- [Benchmarks of uv](https://github.com/astral-sh/uv/blob/main/BENCHMARKS.md)
- [Using uv in GitLab CI/CD](https://docs.astral.sh/uv/guides/integration/gitlab/)
- [uv caching](https://docs.astral.sh/uv/concepts/cache/)
- [Using uv in Docker](https://docs.astral.sh/uv/guides/integration/docker/)
- [GitLab CI/CD cache reference](https://docs.gitlab.com/ci/yaml/#cache)
- [uv pip and pip-tools compatibility](https://docs.astral.sh/uv/pip/compatibility/)
