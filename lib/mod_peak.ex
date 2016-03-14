import Hacks
import Type

defmodule ModPeak do
  # use Types
  # import GraphSpec
  
  # defnode fetch_chromatogram(i: ChromatogramId, outputs: [o: Chromatogram]) do
  #   o.emit(DB.fetch_chromatogram(i))
  # end

  # defnode save_chromatogram(i: Chromatogram, outputs: [o: ChromatogramId]) do
  #   o.emit(DB.save_chromatogram(i))
  # end

  # defnode manually_integrate(ci: Chromatogram, rng: Range, outputs: [co: Chromatogram]) do
  #   co.emit(Compute.manually_integrate(ci, rng))
  # end

  # defgraph mod_peak(
  #   inputs:  [ci: Chromatogram, rng: Range],
  #   outputs: [co: Chromatogram],
  #   nodes:   [manually_integrate],
  #   connections: edges do
  #     this.rng -> manually_integrate.rng
  #     this.ci -> manually_integrate.ci
  #     manually_integrate.co -> this.co
  #   end)
  
  # # fetches a chromatogram from the database,
  # # modifies its peak, and
  # # saves it back to the database
  # defgraph db_mod_peak(
  #   inputs:  [ci: ChromatogramId, rng: Range],
  #   outputs: [co: ChromatogramId],
  #   nodes:   [fetch_chromatogram,
  #             mod_peak,
  #             save_chromatogram],
  #   connections: edges do
  #     this.ci -> fetch_chromatogram.i
  #     this.rng -> mod_peak.rng
  #     fetch_chromatogram.o -> mod_peak.ci
  #     mod_peak.co -> save_chromatogram.i
  #     save_chromatogram.o -> this.co
  #   end)
end
