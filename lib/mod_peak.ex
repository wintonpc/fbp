import Hacks
import Type

defmodule ModPeak do
  use Types
  import GraphSpec
  
  defnode fetch_chromatogram(inp: ChromatogramId, returns: [outp: Chromatogram]) do
    outp.emit(DB.fetch_chromatogram(inp))
  end

  defnode save_chromatogram(inp: Chromatogram, returns: [outp: ChromatogramId]) do
    outp.emit(DB.save_chromatogram(inp))
  end

  defnode manually_integrate(chrom_in: Chromatogram, time_range: Range, returns: [chrom_out: Chromatogram]) do
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

