from pathlib import Path
import typing as T
import numpy as np
import logging
import h5py
from datetime import datetime, timedelta

LSP = 7


def get_simsize(path: Path) -> T.Tuple[int, ...]:
    """
    get simulation size
    """
    path = Path(path).expanduser().resolve()

    with h5py.File(path, "r") as f:
        if "lxs" in f:
            lxs = f["lxs"][:]
        elif "lx1" in f:
            if f["lx1"].ndim > 0:
                lxs = (f["lx1"][:].squeeze()[()], f["lx2"][:].squeeze()[()], f["lx3"][:].squeeze()[()])
            else:
                lxs = (f["lx1"][()], f["lx2"][()], f["lx3"][()])
        else:
            raise KeyError(f"could not find '/lxs' or '/lx1' in {path.as_posix()}")

    return lxs


def write_state(
    time: datetime, ns: np.ndarray, vs: np.ndarray, Ts: np.ndarray, out_dir: Path, file_format: str, realbits: int,
):
    """
     WRITE STATE VARIABLE DATA TO BE USED AS INITIAL CONDITIONS
    FOR ANOTHER SIMULATION.  NOTE THAT WE
    DO NOT HERE OUTPUT ANY OF THE ELECTRODYNAMIC
    VARIABLES SINCE THEY ARE NOT NEEDED TO START THINGS
    UP IN THE FORTRAN CODE.

    INPUT ARRAYS SHOULD BE TRIMMED TO THE CORRECT SIZE
    I.E. THEY SHOULD NOT INCLUDE GHOST CELLS
    """

    fn = out_dir / ("initial_conditions.h5")
    print("write", fn)

    with h5py.File(fn, "w") as f:
        f["/ymd"] = [time.year, time.month, time.day]
        f["/UTsec"] = time.hour * 3600 + time.minute * 60 + time.second + time.microsecond / 1e6

        f.create_dataset(f"/ns", data=ns, dtype=np.float32, compression="gzip", compression_opts=1)
        f.create_dataset(f"/vsx1", data=vs, dtype=np.float32, compression="gzip", compression_opts=1)
        f.create_dataset(f"/Ts", data=Ts, dtype=np.float32, compression="gzip", compression_opts=1)


def readgrid(fn: Path) -> T.Dict[str, np.ndarray]:
    """
    get simulation dimensions

    Parameters
    ----------
    fn: pathlib.Path
        filepath to simgrid.h5

    Returns
    -------
    grid: dict
        grid parameters
    """

    grid: T.Dict[str, T.Any] = {}

    if not fn.is_file():
        logging.error(f"{fn} grid file is not present. Will try to load rest of data.")
        return grid

    grid["lxs"] = get_simsize(fn)

    with h5py.File(fn, "r") as f:
        for key in f.keys():
            grid[key] = f[key][:]

    return grid


def write_grid(p: T.Dict[str, T.Any], xg: T.Dict[str, T.Any]):

    p["out_dir"].mkdir(parents=True, exist_ok=True)

    fn = p["out_dir"] / "simsize.h5"
    print("write", fn)
    with h5py.File(fn, "w") as h:
        for k in ("lx", "lx1", "lx2", "lx3"):
            h[f"/{k}"] = xg[k]

    fn = p["out_dir"] / "simgrid.h5"
    print("write", fn)
    with h5py.File(fn, "w") as h:
        for i in (1, 2, 3):
            for k in (f"x{i}", f"x{i}i", f"dx{i}b", f"dx{i}h", f"h{i}", f"h{i}x1i", f"h{i}x2i", f"h{i}x3i", f"gx{i}", f"e{i}"):
                if xg[k].ndim >= 2:
                    h.create_dataset(f"/{k}", data=xg[k], dtype=np.float32, compression="gzip", compression_opts=1)
                else:
                    h[f"/{k}"] = xg[k].astype(np.float32)

        for k in ("alt", "glat", "glon", "Bmag", "I", "nullpts", "er", "etheta", "ephi", "r", "theta", "phi", "x", "y", "z"):
            if xg[k].ndim >= 2:
                h.create_dataset(f"/{k}", data=xg[k], dtype=np.float32, compression="gzip", compression_opts=1)
            else:
                h[f"/{k}"] = xg[k].astype(np.float32)


def load_Efield(fn: Path) -> T.Dict[str, T.Any]:
    """
    load Efield_inputs files that contain input electric field in V/m
    """

    E: T.Dict[str, np.ndarray] = {}

    sizefn = fn.parent / "simsize.h5"  # NOT the whole sim simsize.dat
    with h5py.File(sizefn, "r") as f:
        E["Nlon"] = f["Nlon"][()]
        E["Nlat"] = f["Nlat"][()]

    gridfn = fn.parent / "simgrid.h5"  # NOT the whole sim simgrid.dat
    with h5py.File(gridfn, "r") as f:
        E["mlon"] = f["mlon"][:]
        E["mlat"] = f["mlat"][:]

    with h5py.File(fn, "r") as f:
        E["flagdirich"] = f["flagdirich"]
        for p in ("Exit", "Eyit", "Vminx1it", "Vmaxx1it"):
            E[p] = [("x2", "x3"), f[p][:]]
        for p in ("Vminx2ist", "Vmaxx2ist"):
            E[p] = [("x2",), f[p][:]]
        for p in ("Vminx3ist", "Vmaxx3ist"):
            E[p] = [("x3",), f[p][:]]

    return E


def loadframe3d_curv(fn: Path) -> T.Dict[str, T.Any]:
    """
    end users should normally use loadframe() instead
    """

    #    grid = readgrid(fn.parent / "inputs/simgrid.h5")
    #    dat = xarray.Dataset(
    #        coords={"x1": grid["x1"][2:-2], "x2": grid["x2"][2:-2], "x3": grid["x3"][2:-2]}
    #    )

    dat: T.Dict[str, T.Any] = {}

    with h5py.File(fn, "r") as f:
        dat["time"] = ymdhourdec2datetime(f["time/ymd"][0], f["time/ymd"][1], f["time/ymd"][2], f["time/UThour"][()])

        dat["ne"] = (("x1", "x2", "x3"), f["/nsall"][LSP - 1, :, :, :].transpose())

        dat["v1"] = (
            ("x1", "x2", "x3"),
            (f["/nsall"][:6, :, :, :].transpose() * f["/vs1all"][:6, :, :, :].transpose()).sum(axis=3) / dat["ne"][1],
        )

        dat["Ti"] = (
            ("x1", "x2", "x3"),
            (f["/nsall"][:6, :, :, :].transpose() * f["/Tsall"][:6, :, :, :].transpose()).sum(axis=3) / dat["ne"][1],
        )
        dat["Te"] = (("x1", "x2", "x3"), f["/Tsall"][LSP - 1, :, :, :].transpose())

        dat["J1"] = (("x1", "x2", "x3"), f["/J1all"][:].transpose())
        dat["J2"] = (("x1", "x2", "x3"), f["/J2all"][:].transpose())
        dat["J3"] = (("x1", "x2", "x3"), f["/J3all"][:].transpose())

        dat["v2"] = (("x1", "x2", "x3"), f["/v2avgall"][:].transpose())
        dat["v3"] = (("x1", "x2", "x3"), f["/v3avgall"][:].transpose())

        dat["Phitop"] = (("x2", "x3"), f["/Phiall"][:])

    return dat


def loadframe3d_curvavg(fn: Path) -> T.Dict[str, T.Any]:
    """
    end users should normally use loadframe() instead

    Parameters
    ----------
    fn: pathlib.Path
        filename of this timestep of simulation output
    """
    #    grid = readgrid(fn.parent / "inputs/simgrid.h5")
    #    dat = xarray.Dataset(
    #        coords={"x1": grid["x1"][2:-2], "x2": grid["x2"][2:-2], "x3": grid["x3"][2:-2]}
    #    )
    dat: T.Dict[str, T.Any] = {}

    with h5py.File(fn, "r") as f:
        dat["time"] = ymdhourdec2datetime(f["time/ymd"][0], f["time/ymd"][1], f["time/ymd"][2], f["/time/UThour"][()])

        dat["ne"] = [("x1", "x2", "x3"), f["/neall"][:].transpose(2, 0, 1)]
        dat["v1"] = [("x1", "x2", "x3"), f["/v1avgall"][:].transpose(2, 0, 1)]
        dat["Ti"] = [("x1", "x2", "x3"), f["/Tavgall"][:].transpose(2, 0, 1)]
        dat["Te"] = [("x1", "x2", "x3"), f["/TEall"][:].transpose(2, 0, 1)]
        dat["J1"] = [("x1", "x2", "x3"), f["/J1all"][:].transpose(2, 0, 1)]
        dat["J2"] = [("x1", "x2", "x3"), f["/J2all"][:].transpose(2, 0, 1)]
        dat["J3"] = [("x1", "x2", "x3"), f["/J3all"][:].transpose(2, 0, 1)]
        dat["v2"] = [("x1", "x2", "x3"), f["/v2avgall"][:].transpose(2, 0, 1)]
        dat["v3"] = [("x1", "x2", "x3"), f["/v3avgall"][:].transpose(2, 0, 1)]
        dat["Phitop"] = [("x2", "x3"), f["/Phiall"][:]]

    return dat


def loadglow_aurmap(fn: Path) -> T.Dict[str, T.Any]:
    """
    read the auroral output from GLOW

    Parameters
    ----------
    fn: pathlib.Path
        filename of this timestep of simulation output
    """

    with h5py.File(fn, "r") as h:
        dat = {"rayleighs": [("wavelength", "x2", "x3"), h["/aurora/iverout"][:]]}

    return dat


def ymdhourdec2datetime(year: int, month: int, day: int, hourdec: float) -> datetime:
    """
    convert year,month,day + decimal hour HH.hhh to time
    """

    return datetime(year, month, day, int(hourdec), int((hourdec * 60) % 60)) + timedelta(seconds=(hourdec * 3600) % 60)


def datetime2ymd_hourdec(dt: datetime) -> str:
    """
    convert datetime to ymd_hourdec string for filename stem
    """

    return dt.strftime("%Y%m%d") + f"_{dt.hour*3600 + dt.minute*60 + dt.second + dt.microsecond/1e6:12.6f}"
