from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb


def _draw_pill(draw_data: DrawData, screen: Screen, tab: TabBarData, index: int) -> int:
    is_active = tab.is_active
    left = f" {index} "
    title = tab.title or ""
    if len(title) > 10:
        title = title[:10] + "..."
    right = f" {title} "

    if is_active:
        left_bg = as_rgb(int(draw_data.active_bg))
        left_fg = as_rgb(int(draw_data.active_fg))
        right_bg = as_rgb(0x232A2D)
        right_fg = as_rgb(int(draw_data.active_bg))
    else:
        left_bg = as_rgb(0x2D3437)
        left_fg = as_rgb(int(draw_data.inactive_fg))
        right_bg = as_rgb(0x1B2225)
        right_fg = as_rgb(int(draw_data.inactive_fg))

    default_bg = as_rgb(int(draw_data.default_bg))

    # rounded left cap
    screen.cursor.bg = default_bg
    screen.cursor.fg = left_bg
    screen.draw("")

    # left segment (number)
    screen.cursor.bg = left_bg
    screen.cursor.fg = left_fg
    screen.draw(left)

    # right segment (title)
    screen.cursor.bg = right_bg
    screen.cursor.fg = right_fg
    screen.draw(right)

    # rounded right cap
    screen.cursor.bg = default_bg
    screen.cursor.fg = right_bg
    screen.draw("")

    # gap between tabs
    screen.cursor.bg = default_bg
    screen.cursor.fg = 0
    screen.draw(" ")
    return screen.cursor.x


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    if index == 1:
        screen.cursor.bg = as_rgb(int(draw_data.default_bg))
        screen.cursor.fg = 0
        screen.draw(" ")
    end = _draw_pill(draw_data, screen, tab, index)
    if is_last:
        screen.cursor.bg = as_rgb(int(draw_data.default_bg))
        screen.cursor.fg = 0
        screen.draw(" " * max(0, screen.columns - screen.cursor.x))
    return end
