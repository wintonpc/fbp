defmodule Types do
  use Type
  deftype_struct CalibratonPoint, fields: [:nom_conc, :response]
  deftype_struct CalibrationMethod, fields: [:weight_strategy, :polynomial_degree, :origin]
  deftype_struct CalibrationCurve, fields: [:coefs]
  deftype_struct Coef, fields: [:name, :value]
  deftype_struct Chromatogram, fields: [:raw_trace, :smooth_trace, :global_baseline, :plot_trace, :is_manually_modified, :peak]
  deftype_struct Trace, fields: [:x, :y]
  deftype_struct Peak, fields: []
  deftype_struct TimeRange, fields: [:a, :b]
  deftype_basic SampleId, extends: String
  deftype_basic AssayId, extends: String
  deftype_basic CompoundName, extends: String
end

