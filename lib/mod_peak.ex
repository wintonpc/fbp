import Hacks
import Type

defmodule ModPeak do
  use Types
  import GraphSpec
  
  defnode fetch_chromatogram(i: ChromatogramId, returns: [o: Chromatogram]) do
    o.emit(DB.fetch_chromatogram(i))
  end

  defnode save_chromatogram(i: Chromatogram, returns: [o: ChromatogramId]) do
    o.emit(DB.save_chromatogram(i))
  end

  defnode manually_integrate(ci: Chromatogram, rng: Range, returns: [co: Chromatogram]) do
    co.emit(Compute.manually_integrate(ci, rng))
  end

  # modifies a peak
  def mod_peak do
    GraphSpec.new(
      :mod_peak,
      inputs:  [ci: Chromatogram, rng: Range],
      outputs: [co: Chromatogram],
      nodes:   [manually_integrate: manually_integrate],
      connections: edges do
        rng -> manually_integrate.rng
        ci -> manually_integrate.ci
        manually_integrate.co -> co
      end)
  end

  # fetches a chromatogram from the database,
  # modifies its peak, and
  # saves it back to the database
  def db_mod_peak do
    GraphSpec.new(
      :db_mod_peak,
      inputs:  [ci: ChromatogramId, rng: Range],
      outputs: [co: ChromatogramId],
      nodes:   [fetch_chromatogram: fetch_chromatogram,
                mod_peak: mod_peak,
                save_chromatogram: save_chromatogram],
      connections: edges do
        ci -> fetch_chromatogram.i
        rng -> mod_peak.rng
        fetch_chromatogram.o -> mod_peak.ci
        mod_peak.co -> save_chromatogram.i
        save_chromatogram.o -> co
      end)
  end
end

