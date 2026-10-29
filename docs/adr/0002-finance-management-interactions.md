# Task-oriented finance management

Date: 2026-10-18. Status: accepted. Ticket: [#38](https://github.com/Drista4real/Project1/issues/38).

The Settings entry is named **Quản lý tài chính**. The management hub explains
each task beside its navigation action and supports Vietnamese search with or
without tone marks. Generated history has its own expandable read-only section,
following ADR 0001. Only modules advertised by the repository are shown.

Tapping a saved record opens a readable detail sheet. Editing is an explicit
action; deletion still requires confirmation after the sheet closes. Existing
overflow shortcuts remain available. Related records are shown by their names.
Loading a record or its references must succeed before exposing its actions.
Failures leave the list available so the user can retry.

Create/edit forms show the main decisions first. Additional fields use an
expandable **Tùy chỉnh thêm** section. Its state is retained when collapsed;
all editable values are validated and saved, including unchanged defaults and
existing values. New required fields without defaults remain visible. Invalid
fields in the collapsed section are revealed before scrolling to the error.
Date defaults for a new recurring schedule start on the current local date.

Leaving a changed, unsaved form requires a discard decision. Canceling keeps the
form and its values. Saving remains accessible above the software keyboard;
the form stays open with its inputs after a save failure.

These changes affect Flutter presentation and interactions. Backend contracts,
financial calculations, and the behavior of scheduled transaction creation are
not changed. The hub, detail sheet and forms use the existing Kakeibo palette
and support light/dark themes, narrow screens and larger text.
