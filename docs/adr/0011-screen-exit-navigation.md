# Back and close actions follow the role of the screen

Date: 2026-11-15. Status: accepted by user request.
Issue: [#105](https://github.com/Drista4real/Project1/issues/105).

Primary destinations do not acquire a back arrow just because a caller pushed
them onto a navigation stack. Secondary screens return to the actual opener.
Entry/edit forms use a close icon; steps inside a flow use a back arrow.
The shared controls use the labels "Quay lại" and "Đóng".

| Screen | Top-left action | Return behavior |
| --- | --- | --- |
| Home, ledger, reports, budget | None | Navigate between the four bottom tabs |
| Forecast embedded in reports | None | Switch report mode within the reports tab |
| Settings | Back | Opener; home when opened directly |
| Spending plan | Back | Opener; home when opened directly or after setup completion |
| Standalone forecast | Back | Opener; reports when opened directly |
| Management hub, resource lists | Back | Previous screen in the management flow |
| Category/envelope management | Back | Opener, which may be budget or settings |
| Transaction detail | Back | Ledger, preserving the changed result used to refresh it |
| Manual transaction create/edit | Close | Opener with the existing save result; ledger when opened directly |
| AI quick input | Close | Opener with the existing save result; home when opened directly |
| Management create/edit form | Close | Opener, retaining the existing unsaved-change confirmation |
| Management read-only form | Back | Opener |
| Monthly setup, first step | Close | Opener; home when opened directly, including during initial loading |
| Monthly setup, later steps | Back | Previous step; "Bỏ qua" exits the entire setup |
| Initial root login | None | The user is at the entry screen |
| Auth registration/OTP/recovery or a pushed auth screen | Back | Existing auth cancellation/return flow, preserving session ownership rules |

Sheets keep their close/dismiss behavior. Arrows that change month, date range
or page are content controls and are not screen-exit actions.

Home opens the spending plan with push so its conversation remains available
on return. Selecting the budget/report tab from its related secondary page
returns to the primary tab instead of doing nothing.

Toolbar actions and Android Back share parent fallbacks for named secondary
routes opened without history. Save/discard guards and returned mutation results
remain owned by the forms. Monthly setup cannot leave or move backwards while
submitting a plan; late defaults/preview responses after closing are ignored.

This decision changes navigation presentation and route history. It does not
change authentication, financial writes, AI inference or the explicit-save rule.
