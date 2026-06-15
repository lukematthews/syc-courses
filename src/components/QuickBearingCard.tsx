type QuickBearingCardProps = {
  onOpen: () => void
}

export function QuickBearingCard({ onOpen }: QuickBearingCardProps) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className="action-card tap-highlight rounded-lg bg-emerald-50 p-4 text-left"
    >
      <div className="text-3xl font-black leading-none text-emerald-950">Quick Bearing</div>
      <p className="mt-3 text-xl font-bold text-emerald-950">Bearing and distance to a mark</p>
    </button>
  )
}
