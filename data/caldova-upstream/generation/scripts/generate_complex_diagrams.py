from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, StrictUndefined, select_autoescape
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
DIAGRAM_ROOT = ROOT / "generation" / "complex-diagrams"
TEMPLATE_ROOT = DIAGRAM_ROOT / "templates"
HTML_ROOT = DIAGRAM_ROOT / "html"
PDF_ROOT = ROOT / "sample-data" / "pdfs"
PROCUREMENT_PATH = ROOT / "sample-data" / "json" / "procurement-chain.json"
INVOICE_PATH = ROOT / "sample-data" / "json" / "waypoint-supplier-invoices.json"
LAND_PATH = DIAGRAM_ROOT / "assets" / "NaturalEarthLand.geojson"
MAP_PATH = DIAGRAM_ROOT / "assets" / "NaturalEarthMap.svg"

WAYPOINT_SITES = [
    {
        "id": "sup-001",
        "name": "Aster Ridge",
        "location": "Research Triangle Park, NC",
        "lat": 35.9042,
        "lon": -78.8738,
        "dx": -105,
        "dy": -55,
        "type": "Manufacturing",
    },
    {
        "id": "sup-002",
        "name": "Northstar Fill Finish",
        "location": "Morrisville, NC",
        "lat": 35.8235,
        "lon": -78.8256,
        "dx": -105,
        "dy": -35,
        "type": "Manufacturing",
    },
    {
        "id": "sup-003",
        "name": "HelioPack",
        "location": "Rotterdam, Netherlands",
        "lat": 51.9244,
        "lon": 4.4777,
        "dx": 14,
        "dy": -35,
        "type": "Packaging",
    },
    {
        "id": "sup-004",
        "name": "Meridian API Works",
        "location": "Singapore",
        "lat": 1.3521,
        "lon": 103.8198,
        "dx": 16,
        "dy": -8,
        "type": "Materials",
    },
    {
        "id": "sup-005",
        "name": "Crescent GMP Labs",
        "location": "Rockville, MD",
        "lat": 39.0840,
        "lon": -77.1528,
        "dx": -2,
        "dy": -87,
        "type": "Testing",
    },
    {
        "id": "sup-006",
        "name": "Summit Dose",
        "location": "Basel, Switzerland",
        "lat": 47.5596,
        "lon": 7.5886,
        "dx": 6,
        "dy": -10,
        "type": "Manufacturing",
    },
    {
        "id": "sup-007",
        "name": "Orchid Clinical",
        "location": "Princeton, NJ",
        "lat": 40.3573,
        "lon": -74.6672,
        "dx": -9,
        "dy": -58,
        "type": "Clinical",
    },
    {
        "id": "sup-008",
        "name": "Valence Cold Chain",
        "location": "Memphis, TN",
        "lat": 35.1495,
        "lon": -90.0490,
        "dx": -100,
        "dy": 16,
        "type": "Logistics",
    },
    {
        "id": "sup-009",
        "name": "BluePeak Biologics",
        "location": "Worcester, MA commercial address",
        "lat": 42.2626,
        "lon": -71.8023,
        "dx": -18,
        "dy": -28,
        "type": "Biologics manufacturing",
    },
    {
        "id": "BPB-US-NH-01",
        "name": "BluePeak inspected site",
        "location": "Portsmouth, NH",
        "lat": 43.0718,
        "lon": -70.7626,
        "dx": -22,
        "dy": 1,
        "type": "Inspected site",
    },
    {
        "id": "sup-010",
        "name": "Keystone Device",
        "location": "Minneapolis, MN",
        "lat": 44.9778,
        "lon": -93.2650,
        "dx": -100,
        "dy": -45,
        "type": "Devices",
    },
    {
        "id": "sup-011",
        "name": "LumaSterile",
        "location": "Cork, Ireland",
        "lat": 51.8985,
        "lon": -8.4756,
        "dx": -70,
        "dy": -12,
        "type": "Sterilization",
    },
    {
        "id": "sup-012",
        "name": "Pioneer Process",
        "location": "Durham, NC",
        "lat": 35.9940,
        "lon": -78.8986,
        "dx": -105,
        "dy": 45,
        "type": "Development",
    },
    {
        "id": "sup-013",
        "name": "Evergreen Excipients",
        "location": "Dublin, Ireland",
        "lat": 53.3498,
        "lon": -6.2603,
        "dx": -75,
        "dy": -37,
        "type": "Materials",
    },
    {
        "id": "sup-014",
        "name": "Atlas Regional",
        "location": "Campinas, Brazil",
        "lat": -22.9056,
        "lon": -47.0608,
        "dx": -92,
        "dy": 10,
        "type": "Manufacturing",
    },
    {
        "id": "sup-015",
        "name": "Signal Ridge",
        "location": "Bethesda, MD",
        "lat": 38.9847,
        "lon": -77.0947,
        "dx": -2,
        "dy": 13,
        "type": "Regulatory",
    },
]

CALDOVA_SITES = [
    {
        "id": "CAL-AP-BOS",
        "name": "Accounts Payable",
        "location": "Boston, MA",
        "lat": 42.3601,
        "lon": -71.0589,
    },
    {
        "id": "CAL-DC-ABE",
        "name": "Distribution Center",
        "location": "Allentown, PA",
        "lat": 40.6023,
        "lon": -75.4714,
    },
]


def project_site(site: dict[str, Any]) -> dict[str, Any]:
    latitude = max(-90.0, min(90.0, float(site["lat"])))
    longitude = max(-180.0, min(180.0, float(site["lon"])))
    return {
        **site,
        "x": round((longitude + 180) / 360 * 1000, 1),
        "y": round((90 - latitude) / 180 * 520, 1),
    }


def polygons(geometry: dict[str, Any]) -> list[list[list[list[float]]]]:
    coordinates = geometry["coordinates"]
    return coordinates if geometry["type"] == "MultiPolygon" else [coordinates]


def point_in_ring(longitude: float, latitude: float, ring: list[list[float]]) -> bool:
    inside = False
    previous = len(ring) - 1
    for current, point in enumerate(ring):
        current_longitude, current_latitude = point[:2]
        previous_longitude, previous_latitude = ring[previous][:2]
        if ((current_latitude > latitude) != (previous_latitude > latitude)) and longitude < (
            (previous_longitude - current_longitude)
            * (latitude - current_latitude)
            / (previous_latitude - current_latitude)
            + current_longitude
        ):
            inside = not inside
        previous = current
    return inside


def site_is_on_land(site: dict[str, Any], land: dict[str, Any]) -> bool:
    longitude = float(site["lon"])
    latitude = float(site["lat"])
    return any(
        point_in_ring(longitude, latitude, rings[0])
        and not any(point_in_ring(longitude, latitude, hole) for hole in rings[1:])
        for feature in land["features"]
        for rings in polygons(feature["geometry"])
    )


def render_world_map(land: dict[str, Any]) -> None:
    paths = []
    for feature in land["features"]:
        for rings in polygons(feature["geometry"]):
            commands = []
            for ring in rings:
                points = [
                    (round((point[0] + 180) / 360 * 1000, 2), round((90 - point[1]) / 180 * 520, 2))
                    for point in ring
                ]
                commands.append("M" + " ".join(f"{x},{y}" for x, y in points) + "Z")
            paths.append(f'<path d="{" ".join(commands)}"/>')
    MAP_PATH.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 520">'
        '<g fill="#bcbcbc" fill-rule="evenodd">' + "".join(paths) + "</g></svg>",
        encoding="utf-8",
    )


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_supplier_sites(invoices: dict[str, Any]) -> list[dict[str, Any]]:
    invoice_by_id = {item["supplier_id"]: item for item in invoices["invoices"]}
    profile_by_id = {
        item["supplier_id"]: item["billing_profile"]
        for item in invoices["document_generation"]["profiles"]
    }
    sites = []
    for geography in WAYPOINT_SITES:
        if not geography["id"].startswith("sup-"):
            continue
        supplier_id = geography["id"]
        profile = profile_by_id[supplier_id]
        sites.append(
            {
                **geography,
                "name": invoice_by_id[supplier_id]["supplier_name"],
                "location": ", ".join(profile["address_lines"][1:]),
            }
        )
    return sites


def validate(
    procurement: dict[str, Any], supplier_sites: list[dict[str, Any]], land: dict[str, Any]
) -> None:
    supplier_ids = {item["id"] for item in supplier_sites}
    expected_ids = {f"sup-{index:03d}" for index in range(1, 16)}
    if supplier_ids != expected_ids:
        raise ValueError("Canonical supplier site register changed")
    bidder_ids = {item["supplier_id"] for item in procurement["suppliers"]}
    if bidder_ids != {"sup-001", "sup-006", "sup-014"}:
        raise ValueError("CALD-201 bidder set changed")
    if len(supplier_sites) != 15:
        raise ValueError("Diagram site register is incomplete")
    offshore_sites = [
        site["id"]
        for site in supplier_sites + CALDOVA_SITES
        if not site_is_on_land(site, land)
    ]
    if offshore_sites:
        raise ValueError(
            f"Map locations are outside Natural Earth land polygons: {', '.join(offshore_sites)}"
        )


def environment() -> Environment:
    env = Environment(
        loader=FileSystemLoader(TEMPLATE_ROOT),
        autoescape=select_autoescape(("html", "xml")),
        undefined=StrictUndefined,
    )
    return env


def render_html(template_name: str, output_name: str, context: dict[str, Any]) -> Path:
    HTML_ROOT.mkdir(parents=True, exist_ok=True)
    output = HTML_ROOT / f"{output_name}.html"
    output.write_text(environment().get_template(template_name).render(**context), encoding="utf-8")
    return output


def render_pdf(html_path: Path, output_name: str) -> None:
    PDF_ROOT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_page(viewport={"width": 1400, "height": 900})
        page.goto(html_path.as_uri(), wait_until="networkidle")
        page.pdf(
            path=PDF_ROOT / f"{output_name}.pdf",
            format="Letter",
            landscape=True,
            print_background=True,
            margin={"top": "0", "right": "0", "bottom": "0", "left": "0"},
        )
        browser.close()


def main() -> None:
    procurement = load_json(PROCUREMENT_PATH)
    invoices = load_json(INVOICE_PATH)
    land = load_json(LAND_PATH)
    supplier_sites = canonical_supplier_sites(invoices)
    validate(procurement, supplier_sites, land)
    render_world_map(land)
    procurement_ids = {item["supplier_id"] for item in procurement["suppliers"]}
    common = {
        "procurement": procurement,
        "supplier_sites": [project_site(site) for site in supplier_sites],
        "procurement_sites": [
            project_site(site) for site in supplier_sites if site["id"] in procurement_ids
        ],
        "caldova_sites": [project_site(site) for site in CALDOVA_SITES],
        "logo_uri": (ROOT / "generation" / "assets" / "caldova_logo.png").as_uri(),
        "world_map_uri": MAP_PATH.as_uri(),
    }
    outputs = [
        ("supplier-network.html.j2", "CAL-MAP-SUP-001", common),
        ("evidence-topology.html.j2", "CAL-MAP-EVD-001", common),
    ]
    for template_name, output_name, context in outputs:
        html_path = render_html(template_name, output_name, context)
        render_pdf(html_path, output_name)
    print(f"Generated {len(outputs)} complex diagram PDFs in {PDF_ROOT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
