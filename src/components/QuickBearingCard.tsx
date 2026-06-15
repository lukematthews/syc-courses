type QuickBearingCardProps = {
  onOpen: () => void
}

export function QuickBearingCard({ onOpen }: QuickBearingCardProps) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className="tap-highlight rounded-lg border-2 border-emerald-950 bg-emerald-100 p-4 text-left shadow-[0_4px_0_#064e3b] transition active:translate-y-1 active:shadow-none"
    >
      <div className="text-3xl font-black leading-none text-emerald-950">Quick Bearing</div>
      <p className="mt-3 text-xl font-bold text-emerald-950">Bearing and distance to a mark</p>
    </button>
  )
}
