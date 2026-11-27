# frozen_string_literal: true

HotCell.limits concurrency: 4, queue_size: 8, queue_wait: 10, deadline: 30, memory: 1536 * 1024**2
