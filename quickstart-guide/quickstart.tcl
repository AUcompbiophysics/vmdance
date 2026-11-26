# VMDance quick start: a tau peptide, from its frames to its clusters.
# The files are BitQT's examples, aligned_tau.pdb and aligned_original_tau_6K.dcd
# (https://github.com/LQCT/BitQT/tree/master/examples). Run it whole:
#   vmd -dispdev text -e quickstart.tcl
# or paste it into VMD's console, a cell at a time: each "# %%" line starts
# a cell, as in VS Code's or Jupyter's Python scripts.
# %% start
package require vmdance
# %% load
# Load the trajectory. Set the two paths to your files: as they are, the
# files are looked for in the folder VMD runs in. A full path works too;
# on Windows, write it with forward slashes (C:/Users/me/tau/aligned_tau.pdb).
set pdb aligned_tau.pdb                ;# <- your PDB
set dcd aligned_original_tau_6K.dcd    ;# <- your DCD
# The PDB is the topology: it names the atoms. Its coordinates come in as
# frame 0, which is not part of the trajectory: load the DCD into the same
# molecule, then delete that first frame.
set m [mol new $pdb waitfor all]
mol addfile $dcd waitfor all molid $m
animate delete beg 0 end 0 $m          ;# 6001 frames left, the DCD's
# %% atoms
# The atoms: the backbone of residues 3 to 12, N CA C O and H
set sel "resid 3 to 12 and name N CA C O H"
# %% fit
# The fit: every frame superposed on frame 999 by those atoms. -fitmove 1
# moves VMD's coordinates there (every frame, the whole molecule) before
# the first scan reads them; the commands after it find them fitted
set fitframe 999
set fit [list -fit $sel -fitframe $fitframe -fitmove 1]
# %% elbow
# How many clusters? The scores at k 2 to 12, and whether the
# clusters change with NANI's seeding (-stability 1)
vmdance elbow -mol $m -sel $sel {*}$fit -kinit CompSim -from 2 -to 12 -stability 1
puts [vmdance alignment -mol $m -sel $sel]   ;# do the frames look superposed?
puts [dict get [vmdance elbow suggest] words]
# %% cluster
# Cluster: k 6, as MDANCE's own tutorial does (the scan says how far
# the four seedings agree on its clusters)
set k 6
vmdance elbow load $k
for {set c 0} {$c < $k} {incr c} {
    set d [vmdance get $c]
    puts "cluster $c: [dict get $d frames] frames,\
          representative frame [dict get $d representative]"
}
puts "mean silhouette: [dict get [vmdance silhouette] mean]"
# %% halves
# Has the run converged? Its two halves, cluster by cluster. Then the
# frames on their first two principal components, and the RMSF of each
# cluster and each half, residue by residue
vmdance groups -blocks 2
puts [vmdance makeup]
puts [dict get [vmdance groups compare] words]
vmdance map
vmdance profiles
# %% second
# A second opinion: the same frames clustered by DIVINE, HELM and eQual,
# and a sweep of three algorithms and two seedings at k 2 to 8
vmdance -mol $m -sel $sel -algorithm divine -k $k
vmdance -mol $m -sel $sel -algorithm helm -k $k -initial 60
vmdance -mol $m -sel $sel -algorithm equal -threshold 8
foreach r [vmdance runs] { puts $r }
vmdance sweep -mol $m -sel $sel -algorithms {kmeans divine helm} -from 2 -to 8 \
    -seedings {StratAll CompSim}
puts [vmdance sweep best db]
# %% keep
# Keep it: back to run 1, then its tables, and the session
vmdance run 1
vmdance export tau_results -prefix tau
vmdance session save tau.vmdance
# (the plots as figures need VMD's window: vmd -e, not -dispdev text)
#   vmdance figures figures -formats {pdf png} -size column
quit
# %% end
