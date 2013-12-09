---
layout: main
title: Before/After Hooks
---

Before/After Hooks
==================

```rb
Model.new(:my_backup, 'My Backup') do
  before do
    # your code
  end

  after do |exit_status|
    # your code
  end
end
```

Before Hooks
------------

The before hook code is run just after Backup logs that the backup has started, before any procedures are performed.

If you need to abort the _model_, your code should raise an exception.

If the exception raised is a `StandardError`, the _model_ will fail with exit status `2`, but additional models/triggers will still be run.

If the exception raised is not a `StandardError`, the _model_ will fail with exit status `3` and no
additional models/triggers will be processed.

In both cases, `on_failure` notifications will be sent.

If _any_ exception is raised (aborting the _model_), the After Hook will **not** be run.


After Hooks
-----------

The after hook code is run just before any `Notifiers` and is guaranteed to run whether or not the backup process was
successful or not;  **unless** a Before Hook raised an Exception and aborted the _model_.

The after hook is passed the model's `exit_status`:

- **0**: Success, no warnings.
- **1**: Success, but warnings were logged.
- **2**: Failure, but additional models/triggers will still be processed.
- **3**: Failure, no additional models/triggers will be processed.

This `exit_status` will determine the type of notification sent after your hook code finishes.
However, your after hook may _increase_ the severity of this `exit_status` before this occurs. `exit_status` will never be _decreased_.

If you log a warning (see below), then the model's `exit_status` will be increased to `1` and `on_warning` notifications will be sent.

If your after hook raises any exceptions, `on_error` notifications will be sent.

If the exception raised is a `StandardError`, the _model_ will fail with exit status `2`,
but additional models/triggers will still be run.

If the exception raised is not a `StandardError`, the _model_ will fail with exit status `3`
and no additional models/triggers will be processed.


Logging
-------

Within both before and after hooks, you may use the Backup [Logger][logging] to log messages.

For informational messages, use `Logger.info "message"`.

For warning messages, use `Logger.warn "message"`.
Logging warning messages will cause `on_warning` notifications to be sent.

Note that using `Logger.error "message"` will have no special effect.
If your hook code experiences an error, it should raise an Exception as noted above.


Multiple Triggers
-----------------

If you're going to run multiple triggers using `backup perform --triggers model_a,model_b`,
you may want to define a _before_ hook on `model_a`, and an _after_ hook on `model_b`.
If you do this, **make sure** your _before_ hook raises a `non-StandardError` exception if it needs to abort the backup
so that `model_b` (and your _after_ hook) is not run.

{% include markdown_links %}
