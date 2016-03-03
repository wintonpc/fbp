import Hacks

# defstruct2 ManuallyIntegrateRequest, [:start_time, :end_time, :chromatogram_id]
defstruct2 Chromatogram, [raw_trace, smooth_trace, global_baseline, plot_trace, is_manually_modified, peak]
defstruct2 Trace, [x, y]
defstruct2 Peak, []
defstruct2 Range, [a, b]

defmodule ModPeak do
  import GraphSpec
  
  defnode fetch_chromatogram(chrom_id: ChromatogramId, returns: [chrom: Chromatogram]) do
    DB.fetch_chromatogram(chrom_id)
  end

  defnode save_chromatogram(chrom: Chromatogram, returns: [chrom_id: ChromatogramId]) do
    DB.save_chromatogram(chrom)
  end

  defnode manually_integrate(chrom_in: Chromatogram, time_range: Range, returns: [chrom_out: Chromatogram]) do
    #chrom_out.emit(Compute.manually_integrate(chrom_in, time_range))
    Compute.manually_integrate(chrom_in, time_range)
  end

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

  def db_mod_peak do
    GraphSpec.new(
      inputs:  [chrom_id_in: ChromatogramId, time_range: Range],
      outputs: [chrom_id_out: ChromatogramId],
      nodes:   [fetcher: fetch_chromatogram,
                modifier: mod_peak,
                saver: save_chromatogram],
      connections: edges do
        chrom_id_in -> fetcher.chrom_id
        time_range -> modifier.time_range
        fetcher.chrom -> modifier.chrom_in
        modifier.chrom_out -> saver.chrom
        saver.chrom_id -> chrom_id_out
      end)
  end

  def render do
    GraphSpec.render_dot(db_mod_peak, "mod_peak")
  end

end


