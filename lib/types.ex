defmodule Array do
  def of(item_type) do
    Type.instantiate_generic(Array, item_type)
  end
end

defmodule AsyncArray do
  def of(item_type) do
    Type.instantiate_generic(AsyncArray, item_type)
  end
end

defmodule Types do
  # deftype_struct CalibratonPoint, fields: [:nom_conc, :response]
  # deftype_struct CalibrationMethod, fields: [:weight_strategy, :polynomial_degree, :origin]
  # deftype_struct CalibrationCurve, fields: [:coefs]
  # deftype_struct Coef, fields: [:name, :value]
  # deftype_struct Chromatogram, fields: [:raw_trace, :smooth_trace, :global_baseline, :plot_trace, :is_manually_modified, :peak]
  # deftype_struct Trace, fields: [:x, :y]
  # deftype_struct Peak, fields: []
  # deftype_struct TimeRange, fields: [:a, :b]
  # deftype_struct CalibrationPoint, fields: []
  def define_all do
    Type.define_basic String, predicate: &Kernel.is_bitstring/1
    Type.define_basic Number, predicate: &Kernel.is_number/1
    Type.define_generic Array, T, predicate: &Kernel.is_list/1
    Type.define_generic AsyncArray, T
  end
  # deftype_basic SampleId, extends: String
  # deftype_basic AssayId, extends: String
  # deftype_basic CompoundName, extends: String
  # deftype_generic Array.of(T)
end

