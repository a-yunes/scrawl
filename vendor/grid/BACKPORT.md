# Checked grid growth

This is crates.io grid 0.18.0, retained under its original MIT license. GPUI
0.2.2 pins Taffy 0.9.0, which requires grid 0.18 and cannot select grid 1.0.1.

Local changes address GHSA-38c5-483c-4qqp by checking dimension addition and
storage multiplication before resizing in both expand_rows and expand_cols.
The regression test runs in release mode, catches overflow panics and verifies
that the original grid remains readable and unchanged for both memory orders.

This is a backport, not a claim that registry grid 0.18.0 is fixed. Version-only
advisory scanners can still flag it. Remove the patch when GPUI supports a Taffy
version using upstream grid >= 1.0.1, after running layout and regression tests.
