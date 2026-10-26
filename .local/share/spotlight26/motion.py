def ease(progress, closing=False):
    progress = min(1.0, max(0.0, progress))
    return progress ** 3 if closing else 1 - (1 - progress) ** 4

class Animator:
    def __init__(self, clock, enabled=True):
        self.clock = clock
        self.enabled = enabled
        self.active = {}

    def cancel(self, key):
        previous = self.active.pop(key, None)
        if previous:
            previous[0].remove_tick_callback(previous[1])

    def cancel_all(self):
        for key in tuple(self.active):
            self.cancel(key)

    def animate(self, key, widget, initial, target, milliseconds, update, complete=None, delay=0, closing=False):
        self.cancel(key)
        if not self.enabled or milliseconds <= 0:
            update(target)
            if complete: complete()
            return
        start = self.clock() + delay * 1000
        duration = milliseconds * 1000
        token = object()
        def tick(_widget, _frame_clock):
            current = self.active.get(key)
            if current is None or current[2] is not token:
                return False
            elapsed = self.clock() - start
            if elapsed < 0:
                return True
            progress = min(1, elapsed / duration)
            update(initial + (target - initial) * ease(progress, closing))
            if progress >= 1:
                self.active.pop(key, None)
                if complete: complete()
                return False
            return True
        callback = widget.add_tick_callback(tick)
        self.active[key] = (widget, callback, token)
