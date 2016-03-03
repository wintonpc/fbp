defmodule Compute do
  import Hacks
  defstruct2 ManualIntegrationRequest, [raw, smooth, global, full_times, start_time, end_time]
  defstruct2 ManualIntegrationSuccess, [plot, plot_times, peak]
  defstruct2 ManualIntegrationFailure, [error]

  def manually_integrate(chrom, time_range) do
    req = %ManualIntegrationRequest{raw: chrom.raw_trace.y,
                                    smooth: chrom.smooth_trace.y,
                                    global: chrom.global_baseline.y,
                                    full_times: chrom.raw_trace.x,
                                    start_time: time_range.a,
                                    end_time: time_range.b}
    
    case NativeCompute.manually_integrate(req) do
      %ManualIntegrationFailure{error: msg} ->
        # report_error(msg)
        chrom
      %ManualIntegrationSuccess{plot: plot, plot_times: plot_times, peak: peak} ->
        %Chromatogram{chrom | plot_trace: %Trace{x: plot_times, y: plot}, peak: peak, is_manually_modified: true}
    end
  end
end
