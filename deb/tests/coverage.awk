# gawk -v runf=FILE -v unitf=FILE -f coverage.awk SCRIPT
# runf/unitf: executed line numbers from real runs / unit tests.
# A line counts as executable unless it is blank, a comment, a bare keyword
# or brace, a heredoc or awk program body, or a backslash continuation.
BEGIN {
	while ((getline l < runf) > 0) run[l] = 1
	while ((getline l < unitf) > 0) unit[l] = 1
	Q = "'"
}
{
	line = $0
	if (heredoc != "") { if (line == heredoc) heredoc = ""; next }
	if (inawk) { if (index(line, "}" Q)) inawk = 0; next }
	cont = prevcont; prevcont = (line ~ /\\$/)
	if (match(line, "<<-?" Q "?([A-Z]+)" Q "?", hm)) heredoc = hm[1]
	if (line ~ /awk / && gsub(Q, Q, line) == 1) inawk = 1
	line = $0

	if (match(line, /^[ \t]*([a-z_][a-z0-9_]*) \(\)/, fm)) {
		indent = substr(line, 1, index(line, fm[1]) - 1)
		if (line ~ /\{.*\}[ \t]*$/) { count(NR, fm[1], line); next }	# one-line function
		cur = fm[1]; curindent = indent; next
	}
	if (cur != "" && substr(line, 1, length(curindent)) == curindent && \
	    substr(line, length(curindent) + 1) ~ /^(}|\); })[ \t]*$/) { cur = ""; next }
	if (cont) next
	if (line ~ /^[ \t]*(#.*)?$/) next
	if (line ~ /^[ \t]*(}|fi|done|esac|else|then|do|;;|\{)[ \t]*$/) next
	if (line ~ /^[ \t]*[^ \t()]+\)[ \t]*(;;)?[ \t]*$/) next		# case pattern without a command
	if (line ~ /^[ \t]*case .* in[ \t]*$/) next			# not shown by xtrace
	count(NR, cur == "" ? "(top level)" : cur, line)
}
function count(n, fn, text) {
	total[fn]++; all++
	if (n in run) { byrun[fn]++; nrun++ }
	else if (n in unit) { byunit[fn]++; unitonly[++nu] = sprintf("%4d %-22s %s", n, fn, text) }
	else missed[++nm] = sprintf("%4d %-22s %s", n, fn, text)
}
END {
	printf "%-22s %6s %6s %6s %6s\n", "function", "lines", "run", "unit", "miss"
	PROCINFO["sorted_in"] = "@ind_str_asc"
	for (fn in total) {
		miss = total[fn] - byrun[fn] - byunit[fn]
		printf "%-22s %6d %6d %6d %6d%s\n", fn, total[fn], byrun[fn], byunit[fn], miss, \
			(byrun[fn] == 0 ? "   <- never runs in a real build" : "")
	}
	printf "\nexecutable lines: %d; covered: %d (%.1f%%); by real runs: %d (%.1f%%)\n", \
		all, all - nm, 100 * (all - nm) / all, nrun, 100 * nrun / all
	print "\nreached only by unit tests:"
	for (i = 1; i <= nu; i++) print unitonly[i]
	print "\nnever executed:"
	for (i = 1; i <= nm; i++) print missed[i]
}
