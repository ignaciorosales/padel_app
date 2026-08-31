import { redirect } from "next/navigation";
import { getViewer, inicioPara } from "@/lib/auth";

export default async function Home() {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");
  redirect(inicioPara(viewer));
}
