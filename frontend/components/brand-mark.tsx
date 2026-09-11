export function BrandMark({
  size = 22,
  className = "",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <img
      src="/brand/mark.png"
      alt=""
      width={size}
      height={size}
      className={className}
      draggable={false}
    />
  );
}
