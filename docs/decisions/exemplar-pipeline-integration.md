# Exemplar Pipeline Integration

## Question

How to wire Exemplar offer/collect into the aggregation and collection pipeline? Currently Exemplar modules exist but are not invoked during record() or MetricReader.collect().

## Decision

TBD — requires:
- Call `Exemplar.Reservoir.offer_to` during each aggregation (record and callback observations)
- Store reservoir state per timeseries (per agg_key in metrics_tab or separate storage)
- Call `Exemplar.Reservoir.collect_from` during MetricReader.collect and attach exemplars to datapoints
- Pass `exemplar_filter` from MeterProvider config through the pipeline
