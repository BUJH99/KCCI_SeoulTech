const fs = require("fs");
const path = require("path");
let pptxgen = global.pptxgen;
if (!pptxgen) {
  pptxgen = require("pptxgenjs");
}

const baseDir = "C:/Users/tbdk5/Desktop/MAIN/0_Working/git/Project/RISCV_RV32I_5STAGE/Presentation";
const slidesDir = path.join(baseDir, "pptx_export", "slides");
const outPath = path.join(baseDir, "RISCV5SOC.pptx");
const videoPath = "C:/Users/tbdk5/Desktop/InBox/한정호.mp4";

async function main() {
  const images = fs
    .readdirSync(slidesDir)
    .filter((file) => /^slide-\d+\.png$/i.test(file))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));

  if (images.length === 0) {
    throw new Error(`No slide screenshots found in ${slidesDir}`);
  }

  if (!fs.existsSync(videoPath)) {
    throw new Error(`Video file not found: ${videoPath}`);
  }

  const pptx = new pptxgen();
  pptx.layout = "LAYOUT_WIDE";
  pptx.author = "한정호";
  pptx.company = "";
  pptx.subject = "RISCV5SOC HTML screenshot export";
  pptx.title = "RISCV5SOC";
  pptx.lang = "ko-KR";
  pptx.theme = {
    headFontFace: "Pretendard",
    bodyFontFace: "Pretendard",
    lang: "ko-KR",
  };
  pptx.margin = 0;

  for (const image of images) {
    const slide = pptx.addSlide();
    slide.background = { color: "FFFFFF" };
    slide.addImage({
      path: path.join(slidesDir, image),
      x: 0,
      y: 0,
      w: 13.333333,
      h: 7.5,
    });
  }

  const videoSlide = pptx.addSlide();
  videoSlide.background = { color: "FFFFFF" };
  videoSlide.addMedia({
    type: "video",
    path: videoPath,
    x: 0,
    y: 0,
    w: 13.333333,
    h: 7.5,
  });

  await pptx.writeFile({ fileName: outPath });
  console.log(`Created ${outPath} with ${images.length + 1} slides`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
