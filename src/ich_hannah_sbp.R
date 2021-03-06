library(tidyverse)
library(readxl)
library(lubridate)
library(mbohelpr)
library(openxlsx)
library(themebg)           
library(officer)
library(rvg)
library(mschart)

pts <- read_excel(
    "U:/Data/stroke_ich/hannah/raw/sbp_fins.xlsx", 
    col_names = c("fin", "sbp_mean", "sbp_median", "sbp_goal"), 
    col_types = c("text", "numeric", "numeric", "numeric"),
    skip = 1
) %>%
    rename_all(str_to_lower) %>%
    distinct() %>%
    select(fin, sbp_goal)

mbo_fin <- edwr::concat_encounters(pts$fin)
print(mbo_fin)

raw_sbp <- read_csv("U:/Data/stroke_ich/hannah/raw/ich_hannah_sbp.csv", locale = locale(tz = "US/Central")) %>%
    rename_all(str_to_lower) %>%
    mutate(across(c(encntr_id, fin, event_id), as.character)) %>%
    arrange(encntr_id, vital_datetime)
    
df_sbp_daily <- raw_sbp %>%
    mutate(vital_date = floor_date(vital_datetime, unit = "day")) %>%
    group_by(fin, vital_date) %>%
    summarize(across(result_val, list(mean = mean, median = median), na.rm = TRUE, .names = "{.fn}"))

df_sbp_goal <- raw_sbp %>%
    group_by(fin) %>%
    mutate(
        sbp_goal_hrs = difftime(vital_datetime, first(vital_datetime), units = "hours"),
        across(sbp_goal_hrs, as.numeric)
    ) %>%
    left_join(pts, by = "fin") %>%
    filter(result_val < sbp_goal) %>%
    distinct(fin, .keep_all = TRUE) %>%
    select(fin, sbp_goal_hrs)

l <- list(
    "sbp_daily" = df_sbp_daily,
    "sbp_goal" = df_sbp_goal
)

write.xlsx(l, paste0("U:/Data/stroke_ich/hannah/final/sbp_data_", today(), ".xlsx"))


# extra -------------------------------------------------------------------

df_sbp_daily_alt <- raw_sbp %>%
    mutate(
        hosp_day = difftime(vital_datetime, arrive_datetime, units = "hours"),
        across(hosp_day, as.numeric),
        across(hosp_day, ~. / 24),
        across(hosp_day, ~if_else(. < 0, 0, .)),
        across(hosp_day, floor),
        across(hosp_day, ~. + 1),
        event = "sbp"
    ) %>%
    filter(hosp_day < 100) %>%
    rename(event_datetime = vital_datetime) %>%
    calc_runtime(vars(fin, hosp_day), id = fin) %>%
    summarize_data(vars(fin, hosp_day), id = fin, result = result_val) %>%
    select(-event, -first_datetime, -last_datetime, -cum_sum, -first_result, -last_result, -auc, -duration)

write.xlsx(df_sbp_daily_alt, "U:/Data/stroke_ich/hannah/final/sbp_data_by_hosp_day.xlsx")


# graph -------------------------------------------------------------------

df_oe <- read_excel("U:/Data/stroke_ich/hannah/raw/pt_groups.xlsx") %>%
    select(
        fin = `Patient`,
        los_oe = `O/E Ratio >0.8 (DELAYED)`
    ) %>%
    mutate(across(fin, as.character))

df_sbp_fig <- df_oe %>%
    inner_join(raw_sbp, by = "fin") %>%
    mutate(
        arrive_sbp_hrs = difftime(vital_datetime, arrive_datetime, units = "hours"),
        across(arrive_sbp_hrs, as.numeric)
    ) %>%
    filter(
        arrive_sbp_hrs >= 0,
        arrive_sbp_hrs <= 96
    )

g_fig <- df_sbp_fig %>%
    ggplot(aes(x = arrive_sbp_hrs, y = result_val, linetype = los_oe)) +
    # geom_point(alpha = 0.5, shape = 1) +
    geom_smooth(color = "black") +
    # ggtitle("Figure 1. Systolic blood pressure in stroke patients with delayed discharge") +
    scale_x_continuous("Hours from arrival", breaks = seq(0, 96, 24)) +
    ylab("Systolic blood pressure (mmHg)") +
    scale_linetype_manual(NULL, values = c("solid", "dotted"), labels = c("LOS O/E < 0.8", "LOS O/E >/= 0.8")) +
    coord_cartesian(ylim = c(100, 200)) +
    theme_bg_print() +
    theme(legend.position = "top")
    
x <- ggplot_build(g_fig)
df_x <- x$data[[1]]

df_fig <- df_x %>%
    select(x, y, group) %>%
    pivot_wider(names_from = group, values_from = y)

write.xlsx(df_fig, "U:/Data/stroke_ich/hannah/final/data_sbp_graph_hannah.xlsx")

s_fig <- ms_scatterchart(data = df_x, x = "x", y = "y", group = "group") %>%
    chart_settings(scatterstyle = "line")

ggsave("figs/hannah_fig1_sbp.jpg", device = "jpeg", width = 8, height = 6, units = "in")

r_fig <- dml(ggobj = g_fig)

pptx <- read_pptx() %>%
    # set_theme(my_theme) %>%
    add_slide(layout = "Title and Content", master = "Office Theme") %>%
    ph_with(r_fig, location = ph_location_type("body")) %>%
    add_slide(layout = "Title and Content", master = "Office Theme") %>%
    ph_with(s_fig, location = ph_location_type("body")) 


print(pptx, target = "report/sbp_fig_hannah.pptx")

