import Hacks
import Type

# defstruct2 ManuallyIntegrateRequest, [:start_time, :end_time, :chromatogram_id]
defstruct2 Chromatogram, [raw_trace, smooth_trace, global_baseline, plot_trace, is_manually_modified, peak]
defstruct2 Trace, [x, y]
defstruct2 Peak, []
defstruct2 Range, [a, b]

defmodule ModPeak do
  import GraphSpec
  
  defnode fetch_chromatogram(inp: ChromatogramId, returns: [outp: Chromatogram]) do
    outp.emit(DB.fetch_chromatogram(inp))
  end

  defnode save_chromatogram(inp: Chromatogram, returns: [outp: ChromatogramId]) do
    outp.emit(DB.save_chromatogram(inp))
  end

  defnode manually_integrate(chrom_in: Chromatogram, time_range: Range, returns: [chrom_out: Chromatogram]) do
    #chrom_out.emit(Compute.manually_integrate(chrom_in, time_range))
    chrom_out.emit(Compute.manually_integrate(chrom_in, time_range))
  end

  # modifies a peak
  def mod_peak do
    GraphSpec.new(
      inputs:  [chrom_in: Chromatogram, time_range: Range],
      outputs: [chrom_out: Chromatogram],
      nodes:   [integrator: manually_integrate],
      connections: edges do
        time_range -> integrator.time_range
        chrom_in -> integrator.chrom_in
        integrator.chrom_out -> chrom_out
      end)
  end

  # fetches a chromatogram from the database,
  # modifies its peak, and
  # saves it back to the database
  def db_mod_peak do
    GraphSpec.new(
      inputs:  [chrom_id_in: ChromatogramId, time_range: Range],
      outputs: [chrom_id_out: ChromatogramId],
      nodes:   [fetcher: fetch_chromatogram,
                modifier: mod_peak,
                saver: save_chromatogram],
      connections: edges do
        chrom_id_in -> fetcher.inp
        time_range -> modifier.time_range
        fetcher.outp -> modifier.chrom_in
        modifier.chrom_out -> saver.inp
        saver.outp -> chrom_id_out
      end)
  end
end

defstruct2 CalibratonPoint, [nom_conc, response]
defstruct2 CalibrationMethod, [weight_strategy, polynomial_degree, origin]
defstruct2 CalibrationCurve, [coefs]
defstruct2 Coef, [name, value]

defmodule Calibrate do
  import GraphSpec

  defnode calculate_calibration_curve(points: Array.of(CalibrationPoint), method: CalibrationMethod,
                                      returns: [curve: CalibrationCurve]) do
    # Compute.calculate_calibration_curve(...)
  end

  defnode fetch_calibration_points(sample_ids: Array.of(SampleId), comp_name: String,
                                   returns: [points: Array.of(CalibrationPoint)]) do
    # DB.fetch(...)
  end

  defnode fetch_calibration_method(assay_id: AssayId, comp_name: String,
                                   returns: [method: CalibrationMethod]) do
    # DB.fetch(...)
  end

  defnode save_calibration_curve(curve: CalibrationCurve, returns: [curve_id: CalibrationCurveId]) do
    # DB.save(...)
  end

  # defnode calculate_calibration_points(compounds: Array.of(Compound), returns: [points: Array.of(CalibrationPoint)]) do
  #   cal_points = Nodular.call_func_parallel(map(compounds, fn comp -> {calculate_calibration_point, [compound: comp]} end))
  #   points.emit(cal_points)
  # end

  # defnode single_adder(a: Bit, b: Bit, returns: [o: Bit, c: Bit]) do
  #   o.emit(a ||| b)
  #   c.emit(a &&& b)
  # end

  # defnode adder(as: Array.of(Bit), bs: Array.of(Bit), returns: [os: Array.of(Bit), cs: Array.of(Bit)]) do
  #   {the_os, the_cs} = Nodular.call_func_parallel(zip(as, bs) |> map(fn {a, b} -> {single_adder, [a: a, b: b]} end))
  #   os.emit(the_os)
  #   cs.emit(the_cs)
  # end

  def db_calculate_calibration_curve do
    GraphSpec.new(
      inputs:  [sample_ids: Array.of(SampleId), comp_name: String, assay_id: AssayId],
      outputs: [curve_id: CalibrationCurveId],
      nodes:   [points_fetcher: fetch_calibration_points,
                method_fetcher: fetch_calibration_method,
                calculator: calculate_calibration_curve,
                saver: save_calibration_curve],
      connections: edges do
        sample_ids -> points_fetcher.sample_ids
        comp_name -> points_fetcher.comp_name
        assay_id -> method_fetcher.assay_id
        comp_name -> method_fetcher.comp_name
        points_fetcher.points -> calculator.points
        method_fetcher.method -> calculator.method
        calculator.curve -> saver.curve
        saver.curve_id -> curve_id
      end)
  end

  quote do
    nodes do
      foo
      bar as barry
    end
  end
  
end
