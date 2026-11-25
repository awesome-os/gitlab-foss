import { defineStore } from 'pinia';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import service from '../services/contributors_service';

export const useContributors = defineStore('contributors', {
  state() {
    return {
      loading: false,
      chartData: null,
    };
  },
  getters: {
    showChart: (state) => Boolean(!state.loading && state.chartData),
    parsedData: (state) => {
      const byAuthorEmail = {};
      const total = {};

      (state.chartData || []).forEach(({ date, author_name: name, author_email: email }) => {
        total[date] = total[date] ? total[date] + 1 : 1;

        const normalizedEmail = email.toLowerCase();
        const authorData = byAuthorEmail[normalizedEmail];

        if (!authorData) {
          byAuthorEmail[normalizedEmail] = {
            name,
            commits: 1,
            dates: {
              [date]: 1,
            },
          };
        } else {
          authorData.commits += 1;
          authorData.dates[date] = authorData.dates[date] ? authorData.dates[date] + 1 : 1;
        }
      });

      return {
        total,
        byAuthorEmail,
      };
    },
  },
  actions: {
    setLoadingState(value) {
      this.loading = value;
    },
    setChartData(chartData) {
      this.chartData = chartData;
    },
    fetchChartData(endpoint) {
      this.setLoadingState(true);

      return service
        .fetchChartData(endpoint)
        .then((res) => res.data)
        .then((data) => {
          this.setChartData(data);
          this.setLoadingState(false);
        })
        .catch(() =>
          createAlert({
            message: __('An error occurred while loading chart data'),
          }),
        );
    },
  },
});
