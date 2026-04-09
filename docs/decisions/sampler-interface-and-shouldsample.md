# Sampler Interface & ShouldSample

## Question

How to define the Sampler behaviour on BEAM? What is the ShouldSample callback signature and SamplingResult structure?

## Decision

TBD

## Compliance

- `compliance/trace-sdk.md` — Sampling + ShouldSample + GetDescription (9 items: processor receives IsRecording, exporter receives Sampled, SampledFlag rules, ShouldSample, GetDescription)
