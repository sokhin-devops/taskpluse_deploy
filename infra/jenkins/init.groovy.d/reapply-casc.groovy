// Runs once at every Jenkins start, after all jobs are loaded.
//
// JCasC creates the Job DSL jobs while Jenkins is still loading jobs from disk,
// and that loading replaces the in-memory job list - so a job that is NEW in
// casc.yaml gets written to disk but not loaded (404 until the next restart).
// Applying the configuration once more here, after loading, registers it.
// Existing jobs and settings are just re-applied unchanged.
io.jenkins.plugins.casc.ConfigurationAsCode.get().configure()
