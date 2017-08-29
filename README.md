# ActiveSparseML
This repo is for GSoC 2017 project Active Set Based Second-order Algorithm for Sparse Learning. 

To install and use the package:
```R
> library(devtools)
> devtools::install_github("sparseML/ActiveSparseML")
> library(picasso)
```

We have implemented a novel high performance square root Lasso solver using active set based second order method in the PICASSO package. With fixed sample size, we change the sample dimension d and report the CPU time for pathwise square root Lasso. For fair comparisons, all three solvers follows the same solution path. 

|         |     d=200     |     d=400     |     d=800      |     d=1600     |
| :-----: | :-----------: | :-----------: | :------------: | :------------: |
| PICASSO | 0.22 (0.01) s | 0.85 (0.01) s | 2.32 (0.10) s  | 2.57 (0.04) s  |
| scalreg | 0.88 (0.11) s | 5.59(0.12) s  | 41.96 (0.88) s | 56.03 (1.34) s |
|  flare  | 83.86(2.30)s  |    > 600 s    |    > 600 s     |    > 600 s     |

The experiments are run in Microsoft R Open 3.3.2 on Mac OS 10.12.3 with 2.4GHz Intel Core i5 and 8GB RAM. For each method and dataset, the experiment is repeated 10 times and we report the mean and standard deviations of the CPU time in the table above. We carefully chose precisions for each algorithm so that the objective function value gap on the last regularization parameter λ are equal for all the algorithms.
