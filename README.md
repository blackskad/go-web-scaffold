# Go Web Template

## What's included

### Basic setup

The main entry point is in `/main.go`, however the web logic will live in `/pkg/web/` for endpoints that return data for human consumption in the browser (HTML, static images, CSS and JS,...) and `/pkg/web/api` for endpoints that return data for programatic consumption (JSON, XML, ...)

### Docker image

While the app can be build and run with plain Go commands, it's intended to be build and run inside a docker container. The Dockerfile contains four stages:

* Base: this layer copies all the files into the Go image and pulls in all the Go mod dependencies.

* Test: this layer builds off of the base layer and runs `go vet` and `go test`. 

* Build: this layer builds off of the base layer and builds the production binaries.

* Production: this layer builds off of the distroless image. It sets up the binary and opens up the required ports in the image.

### Docker compose

To allow you to easily run the service locally without much local config, a docker-compose.yaml file is included. This file will include everything to run a minimal stack.

### GitHub CI pipeline

The project contains a GitHub Actions configuration file to run the docker build stages on `push` to any branch and semver tags, and on `pull_requests` against the `main` branch. It will first run the `test` stage, then it run the `production` stage.

When the pipeline runs for a semver tag, the tag will be embedded in the binary as the application version and the image will be pushed to ghcr. None of the other runs will push a docker image.

While it is recommended to follow [trunk-based development](https://trunkbaseddevelopment.com/), it is not enforced by the build system in any way.

In your GitHub repository, there is an option to configure rulesets for your main branch. Within the ruleset, the success of the build workflow can be made required for each pull requests. For more information, please see the [GitHub documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#require-status-checks-to-pass-before-merging).


### Versioning

The CI pipeline is set up to manage  with a semantic versioning scheme.

* The `main` branch, or trunk is where all the development happens for the next release.
* When a new release should be made, create a new branch `release-${MAJOR}.${MINOR}` and push it to GitHub. Once pushed, a new tag `v${MAJOR}.${MINOR}.0-rc.0` will automatically be created. Once tagged, a new build will kick off for that tag that publishes a docker image with the same tag.
* Every time a new release is made, push a new, empty commit with an incremented tag to the release branch. Every semver tag will kick off


### App configuration

The main configuration will be done through environment variables. The environment package will parse the environment variables into a struct that can then be passed around through the service.

### Profiling

The service always runs with pprof enabled on port 6060. This allows you to fetch runtime profiling information on `http://localhost:6060/debug/pprof`

### Observability

#### Metrics

The service records metrics through the metrics subsystem of Open Telemetry. It has an exporter configured that exposes all metrics on an endpoint `http://localhost:9090/metrics`, in a prometheus-compatible format.

The service will track the Go runtime metrics (goroutines, heap and GC stats) and metrics for the HTTP endpoints.

#### Tracing

The service has tracing set up for the main HTTP mux. All endpoints registered on this mux will create a new trace. During the handling of the endpoint, you can create a new span that is included on the trace of the endpoint by using 

```
	ctx, span := otel.GetTracerProvider().Tracer(environment.AppName).Start(r.Context(), "endpoint-sub-span")
	defer span.End()
```

The open telemetry traces are exported to stdout by default. If the Open Telemetry environment variable `OTEL_EXPORTER_OTLP_ENDPOINT` has been configured, a grpc-based OTLP exporter will be set up.