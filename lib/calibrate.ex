import Hacks
import Type

defmodule Calibrate do
  use Types
  import GraphSpec

  defnode calculate_calibration_curve(points: Array.of(CalibrationPoint), calm: CalibrationMethod,
                                      outputs: [curve: CalibrationCurve]) do
    # Compute.calculate_calibration_curve(...)
  end

  defnode fetch_calibration_points(sids: Array.of(SampleId), cn: CompoundName,
                                   outputs: [points: Array.of(CalibrationPoint)]) do
    # DB.fetch(...)
  end

  defnode fetch_calibration_method(aid: AssayId, cn: CompoundName,
                                   outputs: [calm: CalibrationMethod]) do
    # DB.fetch(...)
  end

  defnode save_calibration_curve(curve: CalibrationCurve, outputs: [ccid: CalibrationCurveId]) do
    # DB.save(...)
  end


  defgraph db_calculate_calibration_curve(
    inputs:  [sids: Array.of(SampleId), cn: CompoundName, aid: AssayId],
    outputs: [ccid: CalibrationCurveId],
    nodes:   [fetch_calibration_points,
              fetch_calibration_method,
              calculate_calibration_curve,
              save_calibration_curve],
    connections: edges do
      this.sids -> fetch_calibration_points.sids
      this.cn -> fetch_calibration_points.cn
      this.aid -> fetch_calibration_method.aid
      this.cn -> fetch_calibration_method.cn
      fetch_calibration_points.points -> calculate_calibration_curve.points
      fetch_calibration_method.calm -> calculate_calibration_curve.calm
      calculate_calibration_curve.curve -> save_calibration_curve.curve
      save_calibration_curve.ccid -> this.ccid
    end)

  defgraph calculate_all_calibration_curves(
    inputs: [sids: Array.of(SampleId),
             aid: AssayId,
             compound_names: AsyncArray.of(CompoundName)],
    outputs: [ccids: AsyncArray.of(CalibrationCurveId)],
    nodes: [calculate_calibration_curve: db_calculate_calibration_curve],
    connections: edges do
      this.sids -> calculate_calibration_curve.sids
      this.aid -> calculate_calibration_curve.aid
      split this.compound_names -> calculate_calibration_curve.cn
      merge calculate_calibration_curve.ccid -> this.ccids
    end)
  
  # def go do
  #   lift_parallel(db_calculate_calibration_curve, multi: [cn: compound_names, ccid: curve_ids])
  # end

end
