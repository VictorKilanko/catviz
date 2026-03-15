text = r"""
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{The Causal Assignment Tree: Formal Framework}
\label{sec:formal}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\subsection{Motivating Example: When TWFE Goes Wrong}

Before stating the formal framework, consider a simple scenario that illustrates why the CAT matters. Suppose we have three groups of states: Group A adopts a policy in 2015, Group B adopts in 2018, and Group C never adopts. A naive researcher runs a TWFE regression and obtains an estimate she reports as the ``average treatment effect.''

What the researcher cannot easily see from the regression output is that TWFE implicitly uses already-treated Group A units as part of the control group for Group B's post-2018 comparison. If Group A's treatment effect grows over time---a perfectly plausible scenario when policies have cumulative effects---then Group A's post-2015 outcomes trend upward relative to the no-treatment counterfactual. Using these contaminated outcomes as controls for Group B biases the Group B estimate downward, and can even yield a negative estimate when the true effect is positive.

The CAT would have caught this immediately. When a researcher draws the CAT for this design, the tree shows that Group A units appear in both the treated branch and---if the researcher naively pools all comparison units---the control branch for Group B. The contamination is visible in the tree topology. The solution is also immediate: restrict comparison leaves to not-yet-treated and never-treated units, exactly as CSDiD prescribes.

\subsection{Formal Definition}

\begin{definition}[Causal Assignment Tree]
\label{def:cat}
A \textbf{Causal Assignment Tree} is a rooted labeled tree $\mathcal{T} = (V, E, \varphi)$ where:
\begin{enumerate}
    \item $V$ is a finite set of nodes with a distinguished root $r \in V$.
    \item $E \subseteq V \times V$ is a set of directed edges from parent to child.
    \item $\varphi: V_{\ell} \to \mathcal{G} \times \mathcal{T} \times \mathcal{Q}$ is the \textbf{assignment function} that maps each leaf node $v \in V_{\ell}$ (where $V_{\ell} \subset V$ denotes the set of leaves) to a unique triple $(g, t, Q)$, where $g \in \mathcal{G}$ indexes the treatment cohort (first treatment date or $\infty$ for never-treated), $t \in \mathcal{T}$ indexes calendar time, and $Q \in \mathcal{Q}$ indexes the subgroup.
    \item Each internal node $v \in V \setminus V_{\ell}$ is labeled by the splitting criterion used at that node (treatment status, cohort, time period, or subgroup).
    \item Each leaf pair $(v_T, v_C)$ designates a treated leaf $v_T$ (with $g < \infty$) and a comparison leaf $v_C$ whose units are not yet treated or never treated at the relevant time.
\end{enumerate}
\end{definition}

\begin{remark}
In a standard $2\times2$ DiD, the CAT has depth 2: the root splits on treatment status, and each branch splits on pre/post period. In CSDiD, the root splits on cohort, producing one branch per timing group plus a never-treated branch. In DDD, a third splitting level is added within each cohort for the subgroup dimension $Q$.
\end{remark}

\subsection{Identifying Assumptions}

\begin{assumption}[Stable Unit Treatment Value -- SUTVA]
\label{ass:sutva}
For each unit $i$ and period $t$: (i) the potential outcome $Y_{it}(d)$ depends only on unit $i$'s own treatment status $d \in \{0,1\}$, not on any other unit's treatment (no interference); and (ii) treatment is binary and well-defined (no hidden variations).
\end{assumption}

\begin{assumption}[No Anticipation]
\label{ass:noant}
For all $t < g_i$ and all $d \in \{0,1\}$:
\[
Y_{it}(d) = Y_{it}(0).
\]
Units do not alter behavior in anticipation of future treatment, so pre-treatment outcomes are valid baselines.
\end{assumption}

\begin{assumption}[Random Sampling]
\label{ass:rs}
The observed panel $\{Y_{it}, G_i, Q_i, X_i\}_{i=1}^{N}$ consists of $N$ i.i.d.\ draws from the population distribution, where $G_i$ is the cohort indicator, $Q_i$ is the subgroup indicator, and $X_i$ is a vector of pre-treatment covariates.
\end{assumption}

\begin{assumption}[Strong Overlap]
\label{ass:overlap}
For all $g$ in the support of $G$ and all $q$ in the support of $Q$:
\[
0 < P(G_i = g \mid X_i) < 1 \quad \text{and} \quad 0 < P(Q_i = q \mid X_i) < 1 \quad \text{a.s.}
\]
Every treated cohort-subgroup cell has valid comparison units with positive probability.
\end{assumption}

\begin{assumption}[Conditional Parallel Trends --- CAT Form]
\label{ass:cpt}
For each leaf pair $(v_T, v_C)$ in the CAT with $\varphi(v_T).\mathrm{cohort} = g$, and for all $t \geq g$:
\[
\mathbb{E}\!\left[Y_t(0) - Y_{g-1}(0) \;\middle|\; i \in \mathrm{leaf}(v_T),\, X_i\right]
= \mathbb{E}\!\left[Y_t(0) - Y_{g-1}(0) \;\middle|\; i \in \mathrm{leaf}(v_C),\, X_i\right] \quad \text{a.s.}
\]
Absent treatment, units in the treated leaf would have trended identically (conditional on $X$) to units in the comparison leaf.
\end{assumption}

\begin{remark}
Assumption~\ref{ass:cpt} is the cohort-specific conditional parallel trends assumption of \citet{Callaway2021} and \citet{SantAnnaZhao2020}, restated at the level of individual leaf pairs. It makes explicit that the identifying assumption must hold \emph{separately} for each leaf pair---not merely on average across cohorts.
\end{remark}

\subsection{Identification Results}

\begin{proposition}[CAT Identification]
\label{prop:id}
Under Assumptions~\ref{ass:sutva}--\ref{ass:cpt}, for each leaf pair $(v_T, v_C)$ with $\varphi(v_T) = (g, t, Q)$, the group-time average treatment effect on the treated
\[
\mathrm{ATT}(g, t) \equiv \mathbb{E}\!\left[Y_{it}(1) - Y_{it}(0) \;\middle|\; G_i = g,\, Q_i = Q\right]
\]
is nonparametrically identified and equals:
\[
\mathrm{ATT}(g, t) = \mathbb{E}\!\left[Y_{it} - Y_{i,g-1} \;\middle|\; i \in \mathrm{leaf}(v_T)\right]
- \mathbb{E}\!\left[Y_{it} - Y_{i,g-1} \;\middle|\; i \in \mathrm{leaf}(v_C)\right].
\]
\end{proposition}

\begin{proof}[Proof sketch]
By Assumption~\ref{ass:noant}, $Y_{i,g-1}(0) = Y_{i,g-1}$ for all units, so pre-period outcomes are observable and equal untreated potential outcomes. Decompose:
\begin{align*}
\mathrm{ATT}(g,t)
&= \mathbb{E}[Y_{it} \mid \mathrm{leaf}(v_T)] - \mathbb{E}[Y_{it}(0) \mid \mathrm{leaf}(v_T)].
\end{align*}
By Assumption~\ref{ass:cpt},
\[
\mathbb{E}[Y_{it}(0) \mid \mathrm{leaf}(v_T)] = \mathbb{E}[Y_{i,g-1} \mid \mathrm{leaf}(v_T)] + \mathbb{E}[Y_{it} - Y_{i,g-1} \mid \mathrm{leaf}(v_C)],
\]
where the last equality uses the fact that $v_C$ units are untreated at time $t$ (so $Y_{it}(0) = Y_{it}$). Substituting yields the stated expression. Consistency of sample analogs follows from Assumptions~\ref{ass:rs} and~\ref{ass:overlap}.
\end{proof}

\begin{proposition}[CAT Completeness]
\label{prop:complete}
The CAT taxonomy is \textbf{complete}: every valid DiD, CSDiD, or DDD estimand satisfying Assumptions~\ref{ass:sutva}--\ref{ass:cpt} corresponds to a unique root-to-leaf-pair path in the CAT, and conversely every leaf pair corresponds to a valid estimand.
\end{proposition}

\begin{proof}[Proof sketch]
By construction. Any estimand $(g, t, Q, C_g)$ determines a unique splitting sequence: root $\to$ cohort $g$ vs.\ $C_g$ $\to$ subgroup $Q$ (if applicable) $\to$ time $t$. The injectivity of $\varphi$ guarantees the path is unique. The converse follows from Proposition~\ref{prop:id}.
\end{proof}

\begin{corollary}[TWFE Validity Condition]
\label{cor:twfe}
Two-way fixed effects (TWFE) regression is a valid estimator of the average ATT if and only if the CAT is \textbf{balanced}: all leaves have equal effective sample sizes and no leaf in a treated branch is simultaneously used as a comparison leaf for another treated cohort.
\end{corollary}

\begin{proof}[Proof sketch]
\citet{GoodmanBacon2021} shows that TWFE equals a weighted average of all implicit $2\times2$ comparisons, including ones that use already-treated units as controls. In CAT terms, such a contaminated comparison arises when a leaf for cohort $g'<g$ (already treated at time $t$) appears as the comparison leaf for cohort $g$ at time $t$---which happens precisely when the CAT is unbalanced. Balancing the CAT eliminates all contaminated comparisons and ensures TWFE weights are non-negative, recovering a proper weighted average of ATTs.
\end{proof}

"""

with open(r'C:\Users\victo\OneDrive\Documents\catviz\R\Paper.txt', 'a', encoding='utf-8') as f:
    f.write(text)
print('Part 2 appended successfully')
