import Hacks

# defstruct2 ManuallyIntegrateRequest, [:start_time, :end_time, :chromatogram_id]
defstruct2 Chromatogram, [raw_trace, smooth_trace, global_baseline, plot_trace, is_manually_modified, peak]
defstruct2 Trace, [x, y]
defstruct2 Peak, []
defstruct2 Range, [a, b]

defmodule ModPeakNodeSpecs do
  import GraphSpec
  
  defnode fetch_chromatogram(i: ChromatogramId, returns: [o: Chromatogram]) do
    
  end

  defnode save_chromatogram(i: Chromatogram, returns: [o: ChromatogramId]) do
    
  end

  defnode manually_integrate(chrom_in: Chromatogram, time_range: Range, returns: [chrom_out: Chromatogram]) do
    #chrom_out.emit(Compute.manually_integrate(chrom_in, time_range))
    Compute.manually_integrate(chrom_in, time_range)
  end

  def mod_peak do
    g = GraphSpec.new(inputs: [time_range: Range,
                               chrom_in: Chromatogram],
                      outputs: [chrom_out: Chromatogram])

    g = GraphSpec.add_nodes(g, integrator: manually_integrate)

    g = GraphSpec.connect_many(g) do
      time_range -> integrator.time_range
      chrom_in -> integrator.chrom_in
      integrator.chrom_out -> chrom_out
    end

    g
  end

  def db_mod_peak do
    g = GraphSpec.new(inputs: [time_range: Range,
                               chrom_id_in: ChromatogramId],
                      outputs: [chrom_id_out: ChromatogramId])

    g = GraphSpec.add_nodes(g,
                            fetcher: fetch_chromatogram,
                            modifier: mod_peak,
                            saver: save_chromatogram)

    g = GraphSpec.connect_many(g) do
      chrom_id_in -> fetcher.i
      time_range -> modifier.time_range
      fetcher.o -> modifier.chrom_in
      modifier.chrom_out -> saver.i
      saver.o -> chrom_id_out
    end
    
    g
  end

  def render do
    GraphSpec.render_dot(mod_peak, "mod_peak")
  end

end


