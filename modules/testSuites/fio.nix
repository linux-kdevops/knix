# SPDX-License-Identifier: copyleft-next-0.3.1
#
# fio: flexible I/O tester.
#
# Upstream: https://github.com/axboe/fio
#
# Ships fio and declares the fio@<name>.service template unit, so a job is
# a systemd object that is started, inspected and stopped by name, and
# whose output is in the journal under one invocation id. The job file is
# written to the unit's state directory before the run, so changing a job
# needs no closure rebuild.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.fio ];

  # %i names a job. Whatever drives the unit writes the job file to
  # /var/lib/fio/%i/job.fio, where StateDirectory= puts the unit's working
  # directory, and reads fio's JSON report back from report.json beside
  # it.
  #
  # Type=oneshot so the start job lasts the whole run and the unit ends
  # with fio's exit code in ExecMainStatus. RemainAfterExit= keeps a job
  # that exited 0 active, with its Result and ExecMainStatus readable,
  # until the caller stops it; a failed job is left failed. So inactive
  # only ever means the job has not run since it was last stopped.
  #
  # fio is one process tree, the unit's cgroup, so the unit is the whole
  # bound: no transient scope underneath, as xfstests' check puts around
  # each of its tests. A caller that wants a deadline sets TimeoutStartSec=
  # in a runtime drop-in; a oneshot unit ignores RuntimeMaxSec=.
  systemd.services."fio@" = {
    description = "fio job %i";
    documentation = [ "https://fio.readthedocs.io/" ];
    # Re-running one job in a loop may exceed systemd's default start rate
    # limit (5 starts per 10 s).
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "fio/%i";
      WorkingDirectory = "%S/fio/%i";
      ExecStart = "${pkgs.fio}/bin/fio --output-format=json --output=report.json job.fio";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      # A job runs as long as its job file says; never let systemd's default
      # start timeout cut it short.
      TimeoutStartSec = "infinity";
      SyslogIdentifier = "fio";
    };
  };
}
