import Hacks
import Type

defmodule Calibrate do
  use Types
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
      inputs:  [sample_ids: Array.of(SampleId), comp_name: CompoundName, assay_id: AssayId],
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

  def calculate_all_calibration_curves do
    GraphSpec.new(
      inputs: [sample_ids: Array.of(SampleId),
               assay_id: AssayId,
               compound_names: AsyncArray.of(CompoundName)],
      outputs: [curve_ids: AsyncArray.of(CalibrationCurveId)],
      nodes: [calculator: db_calculate_calibration_curve],
      connections: edges do
        sample_ids -> calculator.sample_ids
        assay_id -> calculator.assay_id
        split compound_names -> calculator.comp_name
        merge calculator.curve_id -> curve_ids
      end
    )
  end

  # def go do
  #   lift_parallel(db_calculate_calibration_curve, multi: [comp_name: compound_names, curve_id: curve_ids])
  # end

end
